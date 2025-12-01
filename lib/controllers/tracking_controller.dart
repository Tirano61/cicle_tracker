import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../models/live_tracking_data.dart';
import '../services/calorie_calculator.dart';

/// TrackingController: centraliza la lógica de tracking fuera de la UI.
/// Expones ValueNotifiers que los widgets consumirán para evitar setState masivos.
class TrackingController {
  final LocationService _locationService;
  final CalorieCalculator _calorieCalculator;

  // Notifiers públicos
  final ValueNotifier<LatLng?> markerNotifier = ValueNotifier<LatLng?>(null);
  final ValueNotifier<List<LatLng>> polylineFullNotifier = ValueNotifier<List<LatLng>>(<LatLng>[]);
  final ValueNotifier<List<LatLng>> polylineRealtimeNotifier = ValueNotifier<List<LatLng>>(<LatLng>[]);
  // Ruta importada como capa separada
  final ValueNotifier<List<LatLng>> importedRouteNotifier = ValueNotifier<List<LatLng>>(<LatLng>[]);
  final ValueNotifier<bool> isNavigatingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<LiveTrackingData> metricsNotifier = ValueNotifier<LiveTrackingData>(LiveTrackingData());
  final ValueNotifier<bool> isTrackingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  StreamSubscription<LiveTrackingData>? _sub;
  Timer? _calorieTimer;
  Timer? _recalculateTimer;

  // Opciones de control
  final bool _enableAutoRecenter = false; // decide la pantalla, por ahora false

  // Configuración de usuario (peso)
  double weightKg = 70.0;

  // Estado interno para cálculo de calorías
  double _lastCaloriesDistanceKm = 0.0;
  // Navegación por ruta importada
  int _navWaypointIndex = 0;
  double _waypointThresholdMeters = 12.0;
  double _offRouteThresholdMeters = 25.0;
  // Maniobras calculadas a partir de la ruta importada
  final List<Maneuver> _maneuvers = [];
  final ValueNotifier<ManeuverInstruction?> currentManeuverNotifier = ValueNotifier<ManeuverInstruction?>(null);

  TrackingController({LocationService? locationService, CalorieCalculator? calorieCalculator})
      : _locationService = locationService ?? LocationService(),
        _calorieCalculator = calorieCalculator ?? CalorieCalculator();

  /// Permitir ajustar el peso desde la UI/settings
  void setWeightKg(double w) {
    weightKg = w;
  }

  Future<bool> start() async {
    final ok = await _locationService.startTracking();
    if (!ok) {
      lastError.value = 'No se pudo iniciar tracking (GPS/Permisos).';
      return false;
    }

    isTrackingNotifier.value = true;

    // Suscribirse al stream de LocationService
    _sub = _locationService.trackingStream.listen(_onData, onError: (e) {
      lastError.value = e?.toString() ?? 'Error desconocido en tracking';
    });

    // Timer para cálculo de calorías cada 5s (mismo comportamiento previo)
    _calorieTimer?.cancel();
    _calorieTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateCalories());

    _recalculateTimer?.cancel();
    _recalculateTimer = Timer.periodic(const Duration(minutes: 1), (_) => _recalculateCalories());

    return true;
  }

  // Cargar una ruta importada en memoria (no guarda en DB)
  void loadImportedRoute(List<LatLng> points) {
    importedRouteNotifier.value = List<LatLng>.from(points);
    _navWaypointIndex = 0;
    _computeManeuvers(points);
    currentManeuverNotifier.value = null;
  }

  void clearImportedRoute() {
    importedRouteNotifier.value = <LatLng>[];
    isNavigatingNotifier.value = false;
    _navWaypointIndex = 0;
  }

  void startNavigation() {
    if (importedRouteNotifier.value.isEmpty) return;
    _navWaypointIndex = 0;
    isNavigatingNotifier.value = true;
  }

  void stopNavigation() {
    isNavigatingNotifier.value = false;
    currentManeuverNotifier.value = null;
  }

  // Exponer waypoint actual para la UI
  LatLng? get currentNavWaypoint {
    final route = importedRouteNotifier.value;
    if (route.isEmpty) return null;
    if (_navWaypointIndex >= route.length) return null;
    return route[_navWaypointIndex];
  }

  int get navWaypointIndex => _navWaypointIndex;

  void pause() {
    _locationService.pauseTracking();
    isTrackingNotifier.value = false;
    _calorieTimer?.cancel();
    _recalculateTimer?.cancel();
  }

  void resume() {
    _locationService.resumeTracking();
    isTrackingNotifier.value = true;
    _calorieTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateCalories());
    _recalculateTimer = Timer.periodic(const Duration(minutes: 1), (_) => _recalculateCalories());
  }

  void stop() {
    _locationService.stopTracking();
    isTrackingNotifier.value = false;
    _calorieTimer?.cancel();
    _recalculateTimer?.cancel();
  }

  void _onData(LiveTrackingData data) {
    try {
      // Merge de calorías: preservamos las calculadas por el controlador si ya hay más
      final preservedCalories = (metricsNotifier.value.caloriesBurned > data.caloriesBurned)
          ? metricsNotifier.value.caloriesBurned
          : data.caloriesBurned;
      final merged = data.copyWith(caloriesBurned: preservedCalories);

      // Actualizar notifiers específicos
      if (merged.currentLocation != null) {
        markerNotifier.value = merged.currentLocation;

        // Realtime polyline - mantener los últimos 60
        final current = List<LatLng>.from(polylineRealtimeNotifier.value);
        current.add(merged.currentLocation!);
        if (current.length > 60) current.removeRange(0, current.length - 60);
        polylineRealtimeNotifier.value = current;
      }

      // Full polyline (reemplazamos de golpe)
      polylineFullNotifier.value = List<LatLng>.from(merged.routePoints);

      // Metrics
      metricsNotifier.value = merged;

      // Si estamos navegando, actualizar progreso
      if (isNavigatingNotifier.value && merged.currentLocation != null) {
        _updateNavigation(merged.currentLocation!);
      }
      // Actualizar próxima maniobra, siempre que tengamos ubicación
      if (merged.currentLocation != null) {
        _updateManeuver(merged.currentLocation!);
      }
    } catch (e) {
      lastError.value = e.toString();
    }
  }

  void _updateNavigation(LatLng current) {
    final route = importedRouteNotifier.value;
    if (route.isEmpty) return;

    // Índice actual
    if (_navWaypointIndex >= route.length) {
      // Llegamos al final
      isNavigatingNotifier.value = false;
      return;
    }

    final Distance distance = Distance();
    final next = route[_navWaypointIndex];
    final meters = distance.as(LengthUnit.Meter, current, next);

    if (meters <= _waypointThresholdMeters) {
      _navWaypointIndex++;
      if (_navWaypointIndex >= route.length) {
        isNavigatingNotifier.value = false;
      }
    } else {
      // Si estamos muy lejos de la ruta, marcar off-route (podemos usar lastError para notificar)
      final nearestDist = _distanceToRouteMeters(current, route);
      if (nearestDist > _offRouteThresholdMeters) {
        lastError.value = 'TE HAS DESVÍO DE LA RUTA';
      }
    }
  }

  /// Encuentra el índice del punto de la ruta importada más cercano a la posición dada.
  /// Retorna -1 si no hay ruta cargada.
  int findClosestIndexTo(LatLng current) {
    final route = importedRouteNotifier.value;
    if (route.isEmpty) return -1;
    final Distance distance = Distance();
    double minDist = double.infinity;
    int idx = -1;
    for (var i = 0; i < route.length; i++) {
      final d = distance.as(LengthUnit.Meter, current, route[i]);
      if (d < minDist) {
        minDist = d;
        idx = i;
      }
    }
    return idx;
  }

  /// Devuelve la distancia en metros al punto de la ruta importada más cercano.
  /// Retorna `double.infinity` si no hay ruta.
  double distanceToClosest(LatLng current) {
    final route = importedRouteNotifier.value;
    if (route.isEmpty) return double.infinity;
    final Distance distance = Distance();
    double minDist = double.infinity;
    for (final p in route) {
      final d = distance.as(LengthUnit.Meter, current, p);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// Intenta iniciar la navegación colocándose en el waypoint más cercano.
  /// Si la distancia al punto más cercano es menor o igual a `thresholdMeters`,
  /// la navegación se inicia y retorna true. Si la ruta no está cargada retorna false.
  bool attemptAutoStartNavigation(LatLng current, {double thresholdMeters = 50.0}) {
    final route = importedRouteNotifier.value;
    if (route.isEmpty) return false;
    final idx = findClosestIndexTo(current);
    if (idx < 0) return false;
    final dist = distanceToClosest(current);
    _navWaypointIndex = idx;
    if (dist <= thresholdMeters) {
      isNavigatingNotifier.value = true;
      return true;
    }
    return false;
  }

  double _distanceToRouteMeters(LatLng current, List<LatLng> route) {
    final Distance distance = Distance();
    double minDist = double.infinity;
    for (final p in route) {
      final d = distance.as(LengthUnit.Meter, current, p);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  // --- Maneuver helpers ---
  void _computeManeuvers(List<LatLng> route) {
    _maneuvers.clear();
    if (route.length < 3) return;
    for (var i = 1; i < route.length - 1; i++) {
      final prev = route[i - 1];
      final cur = route[i];
      final next = route[i + 1];
      final b1 = _bearingBetween(prev, cur);
      final b2 = _bearingBetween(cur, next);
      var delta = (b2 - b1) % 360.0;
      if (delta > 180) delta -= 360;
      final ang = delta.abs();
      if (ang >= 25.0) {
        final turn = (delta > 0) ? 'right' : 'left';
        _maneuvers.add(Maneuver(index: i, turn: turn, angle: ang));
      }
    }
  }

  double _bearingBetween(LatLng a, LatLng b) {
    final lat1 = _toRad(a.latitude);
    final lat2 = _toRad(b.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final br = _toDeg(math.atan2(y, x));
    return (br + 360) % 360;
  }

  double _toRad(double deg) => deg * math.pi / 180.0;
  double _toDeg(double rad) => rad * 180.0 / math.pi;

  void _updateManeuver(LatLng current) {
    if (_maneuvers.isEmpty || importedRouteNotifier.value.isEmpty) {
      currentManeuverNotifier.value = null;
      return;
    }
    final route = importedRouteNotifier.value;
    // encontrar la primera maniobra cuyo índice esté por encima del waypoint actual
    Maneuver? nextM;
    for (final m in _maneuvers) {
      if (m.index >= _navWaypointIndex) {
        nextM = m;
        break;
      }
    }
    if (nextM == null) {
      currentManeuverNotifier.value = null;
      return;
    }
    final target = route[nextM.index];
    final Distance distance = Distance();
    final meters = distance.as(LengthUnit.Meter, current, target);
    final instr = ManeuverInstruction(
      index: nextM.index,
      turn: nextM.turn,
      angle: nextM.angle,
      distanceMeters: meters,
    );
    currentManeuverNotifier.value = instr;
  }


  void _updateCalories() {
    final data = metricsNotifier.value;
    if (!data.isTracking || data.isPaused) return;

    final intervalCaloriesBySpeed = _calorieCalculator.estimateCaloriesForInterval(
      weightKg: weightKg,
      recentSpeeds: data.speeds,
      intervalSeconds: 5,
      currentSpeedKmh: data.currentSpeedKmh > 0.5 ? data.currentSpeedKmh : null,
    );

    double intervalCalories = intervalCaloriesBySpeed;
    final distanceDeltaKm = (data.distanceKm - _lastCaloriesDistanceKm).clamp(0.0, double.infinity);
    double fallbackCalories = 0.0;
    if ((intervalCaloriesBySpeed <= 0.0) && distanceDeltaKm > 0.0) {
      final caloriesPerKm = _calorieCalculator.getCaloriesPerKm(weightKg);
      fallbackCalories = caloriesPerKm * distanceDeltaKm;
      intervalCalories = fallbackCalories;
    }

    final newCalories = metricsNotifier.value.caloriesBurned + intervalCalories;
    metricsNotifier.value = metricsNotifier.value.copyWith(caloriesBurned: newCalories);

    // Actualizar marcador de distancia para el siguiente intervalo
    _lastCaloriesDistanceKm = data.distanceKm;
  }

  void _recalculateCalories() {
    final data = metricsNotifier.value;
    if (!data.isTracking) return;

    final totalCalories = _calorieCalculator.calculateCaloriesWithLimitedData(
      weightKg: weightKg,
      elapsedTime: data.elapsedTime,
      totalDistanceKm: data.distanceKm,
      recentSpeeds: data.speeds,
      currentSpeedKmh: data.currentSpeedKmh,
    );

    metricsNotifier.value = metricsNotifier.value.copyWith(caloriesBurned: totalCalories);
  }

  void dispose() {
    _sub?.cancel();
    _calorieTimer?.cancel();
    _recalculateTimer?.cancel();
    markerNotifier.dispose();
    polylineFullNotifier.dispose();
    polylineRealtimeNotifier.dispose();
    metricsNotifier.dispose();
    isTrackingNotifier.dispose();
    lastError.dispose();
    currentManeuverNotifier.dispose();
  }
}

class Maneuver {
  final int index;
  final String turn; // 'left'|'right'
  final double angle;
  Maneuver({required this.index, required this.turn, required this.angle});
}

class ManeuverInstruction {
  final int index;
  final String turn;
  final double angle;
  final double distanceMeters;
  ManeuverInstruction({required this.index, required this.turn, required this.angle, required this.distanceMeters});
}
