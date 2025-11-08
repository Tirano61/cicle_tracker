import 'dart:async';

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
    } catch (e) {
      lastError.value = e.toString();
    }
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
  }
}
