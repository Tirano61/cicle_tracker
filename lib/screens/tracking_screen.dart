import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../services/calorie_calculator.dart';
import '../models/live_tracking_data.dart';
import '../models/cycling_session.dart';
import '../models/user_settings.dart';
import '../widgets/metrics_panel.dart';
import '../widgets/tracking_controls.dart';
import '../widgets/cached_tile_layer.dart';
import '../widgets/map_provider_selector.dart';
import '../models/map_tile_provider.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'argentina_download_screen.dart';
import '../services/map_cache_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  final PreferencesService _preferencesService = PreferencesService();
  final CalorieCalculator _calorieCalculator = CalorieCalculator();
  final MapController _mapController = MapController();
  final Distance _distanceUtil = const Distance();
  final ValueNotifier<LatLng?> _markerNotifier = ValueNotifier<LatLng?>(null);
  // Notifier to hold full polyline points so the map layer can update
  // without rebuilding the whole widget tree on every incoming point.
  final ValueNotifier<List<LatLng>> _polylineNotifier = ValueNotifier<List<LatLng>>(<LatLng>[]);
  // Lightweight realtime polyline showing the most recent points (updated on every fix)
  final ValueNotifier<List<LatLng>> _realtimePolylineNotifier = ValueNotifier<List<LatLng>>(<LatLng>[]);
  DateTime _lastPolylineUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  int? _sessionMaxZoom;
  StreamSubscription<int?>? _sessionZoomSub;
  bool _userInteracted = false; // true cuando el usuario ha hecho pan/zoom manual
  double _mapRotation = 0.0; // grados
  DateTime? _lastZoomWarning;
  final Duration _zoomWarnInterval = const Duration(seconds: 3);
  // Map recenter control to avoid visual jumps
  DateTime _lastMapMove = DateTime.fromMillisecondsSinceEpoch(0);
  LatLng? _lastMapCenter;
  final double _mapMoveMinMeters = 15.0;

  StreamSubscription<LiveTrackingData>? _trackingSubscription;
  
  LiveTrackingData _trackingData = LiveTrackingData();
  UserSettings _userSettings = UserSettings();
  // Animated marker state to smooth visual jumps
  LatLng? _markerAnimatedPos;
  Timer? _markerAnimationTimer;
  Duration _markerAnimationDuration = const Duration(milliseconds: 300);
  // Debug flag: when false, the map will not automatically recenter.
  // This is useful to determine whether camera movements are the cause
  // of perceived jumps at corners. Set to true to restore original behavior.
  final bool _enableAutoRecenter = false;
  LatLng? _markerAnimationFrom;
  LatLng? _markerAnimationTo;
  MapTileProvider _currentMapProvider = MapTileProvider.openStreetMap;
  bool _isMapReady = false;
  Timer? _calorieTimer;
  Timer? _recalculateTimer;
  double _lastCaloriesDistanceKm = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _initializeLocation();
    _listenToTracking();
    // Escuchar cambios en el session max zoom
    _sessionZoomSub = MapCacheService().sessionZoomStream.listen((z) {
      setState(() {
        _sessionMaxZoom = z;
      });
    });
  }

  void _animateMarkerTo(LatLng target) {
    // Cancel previous
    _markerAnimationTimer?.cancel();

    final from = _markerAnimatedPos ?? _trackingData.currentLocation;
    if (from == null) {
      // Direct set
      _markerAnimatedPos = target;
      _markerNotifier.value = target;
      try {
        // ignore: avoid_print
        print('[MarkerUpdate] ${target.latitude.toStringAsFixed(6)},${target.longitude.toStringAsFixed(6)}');
      } catch (_) {}
      return;
    }

    _markerAnimationFrom = from;
    _markerAnimationTo = target;
    final start = DateTime.now();
    final durationMs = _markerAnimationDuration.inMilliseconds;

    _markerAnimationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final t = (elapsed / durationMs).clamp(0.0, 1.0);
      final lat = _lerpDouble(_markerAnimationFrom!.latitude, _markerAnimationTo!.latitude, t);
      final lon = _lerpDouble(_markerAnimationFrom!.longitude, _markerAnimationTo!.longitude, t);
      final pos = LatLng(lat, lon);
      _markerAnimatedPos = pos;
      _markerNotifier.value = pos;
      try {
        // ignore: avoid_print
        print('[MarkerUpdate] ${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}');
      } catch (_) {}
      if (t >= 1.0) {
        timer.cancel();
        _markerAnimationTimer = null;
      }
    });
  }

  double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    _calorieTimer?.cancel();
    _recalculateTimer?.cancel();
    _locationService.dispose();
    _markerAnimationTimer?.cancel();
    _markerNotifier.dispose();
    _polylineNotifier.dispose();
    _realtimePolylineNotifier.dispose();
    _sessionZoomSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserSettings() async {
    final settings = await _preferencesService.loadUserSettings();
    final mapProvider = await _preferencesService.getMapProvider();
    if (!mounted) return;
    setState(() {
      _userSettings = settings;
      _currentMapProvider = mapProvider;
    });
  }

  Future<void> _initializeLocation() async {
    final currentLocation = await _locationService.getCurrentLocation();
    if (currentLocation != null && _isMapReady && !_userInteracted) {
      _mapController.move(currentLocation, 16.0);
    }
  }

  void _listenToTracking() {
    _trackingSubscription = _locationService.trackingStream.listen((data) {
      // Merge incoming state with locally tracked calories to avoid
      // that the LocationService (which doesn't compute calories)
      // overwrite the UI-calculated calories (was causing 0.0 siempre).
      final double preservedCalories = (_trackingData.caloriesBurned > data.caloriesBurned)
          ? _trackingData.caloriesBurned
          : data.caloriesBurned;
      final merged = data.copyWith(caloriesBurned: preservedCalories);

      // DEBUG: mostrar el valor de calorías que aplicaremos
      try {
        // ignore: avoid_print
        print('[TrackingStream] incomingCalories=${data.caloriesBurned} preserved=$preservedCalories merged=${merged.caloriesBurned}');
      } catch (_) {}

      // Update lightweight marker notifier every update (fast)
      if (merged.currentLocation != null) {
        _animateMarkerTo(merged.currentLocation!);
      }

      // Throttle polyline redraws: update points only every N points or every second
      final now = DateTime.now();
      // Realtime polyline: append the latest point (keep last 60 points to avoid unbounded memory)
      if (merged.currentLocation != null) {
        final current = List<LatLng>.from(_realtimePolylineNotifier.value);
        current.add(merged.currentLocation!);
        if (current.length > 60) current.removeRange(0, current.length - 60);
        _realtimePolylineNotifier.value = current;
      }

      final shouldUpdatePolyline = (merged.routePoints.length - _polylineNotifier.value.length) >= 1 || now.difference(_lastPolylineUpdate) > const Duration(milliseconds: 250);
      if (shouldUpdatePolyline) {
        final copy = List<LatLng>.from(merged.routePoints);
        _polylineNotifier.value = copy;
        _lastPolylineUpdate = now;
        try {
          // ignore: avoid_print
          print('[PolylineUpdate] points=${copy.length}');
        } catch (_) {}
      }

      setState(() {
        // Keep tracking data for metrics; polyline rendering reads _polylinePointsForMap
        _trackingData = merged;
      });

      // Mover mapa a ubicación actual si está trackeando (solo si el usuario no intervino)
      // This behavior is gated by _enableAutoRecenter for debugging purposes.
      if (_enableAutoRecenter && data.isTracking && data.currentLocation != null && _isMapReady && !_userInteracted) {
        final now = DateTime.now();
        final meters = (_lastMapCenter == null)
            ? double.infinity
            : _distanceUtil.as(LengthUnit.Meter, _lastMapCenter!, data.currentLocation!);
        // Solo mover si pasó suficiente tiempo y la distancia es significativa
        if (now.difference(_lastMapMove) > const Duration(milliseconds: 800) && meters >= _mapMoveMinMeters) {
          _mapController.move(data.currentLocation!, 16.0);
          _lastMapMove = now;
          _lastMapCenter = data.currentLocation!;
        }
      }
    });
  }

  Future<void> _startTracking() async {
    final success = await _locationService.startTracking();
    if (!success) {
      _showErrorDialog('Error de GPS', 
          'No se pudo acceder al GPS. Verifica que los permisos estén habilitados.');
      return;
    }

    // Iniciar timer para calcular calorías
    _calorieTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_trackingData.isTracking && !_trackingData.isPaused) {
        _updateCalories();
      }
    });
    // Inicializar marcador de distancia para el cálculo de calorías
    _lastCaloriesDistanceKm = _trackingData.distanceKm;

    // Iniciar timer para recálculo periódico de precisión (cada minuto)
    _recalculateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_trackingData.isTracking) {
        _recalculateCalories();
      }
    });

  if (!mounted) return;
  _showSnackBar('¡Tracking iniciado!', Theme.of(context).colorScheme.primary);
  }

  void _pauseTracking() {
    _locationService.pauseTracking();
    _calorieTimer?.cancel();
    _recalculateTimer?.cancel();
  _showSnackBar('Tracking pausado', Theme.of(context).colorScheme.secondary);
  }

  void _resumeTracking() {
    _locationService.resumeTracking();
    
    // Reiniciar timer de calorías
    _calorieTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_trackingData.isTracking && !_trackingData.isPaused) {
        _updateCalories();
      }
    });
    // Alinear referencia de distancia para evitar doble conteo tras pausa
    _lastCaloriesDistanceKm = _trackingData.distanceKm;

    // Reiniciar timer de recálculo
    _recalculateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_trackingData.isTracking) {
        _recalculateCalories();
      }
    });

  _showSnackBar('Tracking reanudado', Theme.of(context).colorScheme.primary);
  }

  Future<void> _stopTracking() async {
    _locationService.stopTracking();
    _calorieTimer?.cancel();
    _recalculateTimer?.cancel();

    // Guardar sesión si hay datos válidos
    if (_trackingData.distanceKm > 0.1 && _trackingData.elapsedTime.inMinutes > 1) {
  await _saveSession();
  if (!mounted) return;
  _showSnackBar('¡Sesión guardada!', Theme.of(context).colorScheme.primary);
    }

    _locationService.resetTracking();
  if (!mounted) return;
  _showSnackBar('Tracking detenido', Theme.of(context).colorScheme.error);
  }

  

  void _updateCalories() {
    if (!_trackingData.isTracking || _trackingData.isPaused) return;

    // Intentar cálculo por velocidad/tiempo
    final intervalCaloriesBySpeed = _calorieCalculator.estimateCaloriesForInterval(
      weightKg: _userSettings.weightKg,
      recentSpeeds: _trackingData.speeds,
      intervalSeconds: 5, // Actualización cada 5 segundos
      currentSpeedKmh: _trackingData.currentSpeedKmh > 0.5 ? _trackingData.currentSpeedKmh : null,
    );

    double intervalCalories = intervalCaloriesBySpeed;

    // Si no devolvió nada útil, usar fallback por distancia recorrida en el intervalo
    final distanceDeltaKm = (_trackingData.distanceKm - _lastCaloriesDistanceKm).clamp(0.0, double.infinity);
    double fallbackCalories = 0.0;
    if ((intervalCaloriesBySpeed <= 0.0) && distanceDeltaKm > 0.0) {
      final caloriesPerKm = _calorieCalculator.getCaloriesPerKm(_userSettings.weightKg);
      fallbackCalories = caloriesPerKm * distanceDeltaKm;
      intervalCalories = fallbackCalories;
    }

    // DEBUG: imprimir diagnóstico de cálculo de calorías
    // Solo print para debugging; será controlado por un flag dedicado más adelante.
    try {
      // Evitar usar print en release si es eliminado por lint; este es temporal para pruebas.
      // Muestra: distanceDeltaKm, intervalCaloriesBySpeed, fallbackCalories, intervalCalories
      // ignore: avoid_print
      print('[CaloriesDebug] distanceDeltaKm=$distanceDeltaKm intervalBySpeed=$intervalCaloriesBySpeed fallback=$fallbackCalories finalInterval=$intervalCalories totalBefore=${_trackingData.caloriesBurned}');
    } catch (_) {}

    final newCalories = _trackingData.caloriesBurned + intervalCalories;

    // Actualizar último marcador de distancia
    _lastCaloriesDistanceKm = _trackingData.distanceKm;

    setState(() {
      _trackingData = _trackingData.copyWith(caloriesBurned: newCalories);
    });
  }

  /// Recalcular calorías totales usando todos los datos disponibles
  /// Se llama periódicamente para corregir la precisión
  void _recalculateCalories() {
    if (!_trackingData.isTracking) return;

    final totalCalories = _calorieCalculator.calculateCaloriesWithLimitedData(
      weightKg: _userSettings.weightKg,
      elapsedTime: _trackingData.elapsedTime,
      totalDistanceKm: _trackingData.distanceKm,
      recentSpeeds: _trackingData.speeds,
      currentSpeedKmh: _trackingData.currentSpeedKmh,
    );

    setState(() {
      _trackingData = _trackingData.copyWith(caloriesBurned: totalCalories);
    });
  }

  Future<void> _saveSession() async {
    final session = CyclingSession(
      startTime: _trackingData.startTime ?? DateTime.now(),
      endTime: DateTime.now(),
      distanceKm: _trackingData.distanceKm,
      averageSpeedKmh: _trackingData.averageSpeedKmh,
      maxSpeedKmh: _trackingData.maxSpeedKmh,
      caloriesBurned: _trackingData.caloriesBurned,
      duration: _trackingData.elapsedTime,
      routePoints: _trackingData.routePoints,
      speeds: [], // Simplificado por ahora
      isCompleted: true,
    );

    await _databaseService.insertCyclingSession(session);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeMapProvider(MapTileProvider newProvider) async {
    if (newProvider != _currentMapProvider) {
      setState(() {
        _currentMapProvider = newProvider;
      });
      
      // Guardar la preferencia
      await _preferencesService.saveMapProvider(newProvider);
      
      // Mostrar confirmación
    if (!mounted) return;
    _showSnackBar('Mapa cambiado a ${newProvider.name}', Theme.of(context).colorScheme.primary);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
          child: Center(
              child: Icon(
              Icons.wifi,
              color: Theme.of(context).colorScheme.onPrimary.withAlpha((0.9 * 255).round()),
              size: 20,
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚴‍♂️ CycleTracker'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          // Indicador de estado de mapas
          _buildConnectionIndicator(),
          // Selector de tipo de mapa
          MapProviderSelector(
            currentProvider: _currentMapProvider,
            onProviderChanged: _changeMapProvider,
            isCompact: true,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar Argentina',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ArgentinaDownloadScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ).then((_) => _loadUserSettings()),
          ),
        ],
      ),
      body: Column(
        children: [
          // Mapa
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(40.7128, -74.0060), // Nueva York por defecto
                    // Inicializar zoom inicial a 12 si session limita, sino 16
                    initialZoom: (_sessionMaxZoom != null && (_sessionMaxZoom! < 16)) ? _sessionMaxZoom!.toDouble() : 16.0,
                    onMapReady: () {
                      _isMapReady = true;
                      _initializeLocation();
                    },
                    maxZoom: _sessionMaxZoom?.toDouble() ?? 18.0,
                    // Detectar interacción del usuario (pan/zoom) y rotación
                    onPositionChanged: (pos, hasGesture) {
                      if (hasGesture == true) {
                        setState(() {
                          _userInteracted = true;
                        });
                      }
                      // Algunos MapPosition exponen 'rotation' en grados
                      try {
                        final rot = pos.rotation;
                        setState(() {
                          _mapRotation = rot;
                        });
                      } catch (_) {
                        // Si no existe la propiedad, ignoramos
                      }

                      // Protección: si la sesión tiene un maxZoom y el usuario intenta forzar más, revertimos y avisamos
                      try {
                        final currentZoom = pos.zoom;
                        if (_sessionMaxZoom != null && currentZoom > _sessionMaxZoom!) {
                          // Throttlear notificación para no spammear
                          final now = DateTime.now();
                          if (_lastZoomWarning == null || now.difference(_lastZoomWarning!) > _zoomWarnInterval) {
                            _lastZoomWarning = now;
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Zoom limitado a ${_sessionMaxZoom} porque estás usando mapas descargados'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }

                          // Forzar zoom de vuelta al máximo permitido
                          try {
                            final center = pos.center;
                            // Mover mapa al zoom máximo permitido
                            _mapController.move(center, _sessionMaxZoom!.toDouble());
                          } catch (e) {
                            // ignorar errores de move
                          }
                        }
                      } catch (_) {
                        // ignorar si pos.zoom no está disponible
                      }
                    },
                  ),
                  children: [
                    CachedTileLayer(
                      tileProvider: _currentMapProvider,
                      userAgentPackageName: 'com.example.cicle_app',
                    ),
                // Ruta recorrida (actualizada vía ValueNotifier para evitar rebuilds pesados)
                ValueListenableBuilder<List<LatLng>>(
                  valueListenable: _polylineNotifier,
                  builder: (context, points, child) {
                    if (points.isEmpty) return const SizedBox.shrink();
                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          strokeWidth: 4.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    );
                  },
                ),
                // Realtime trailing polyline (shows recent movement smoothly)
                ValueListenableBuilder<List<LatLng>>(
                  valueListenable: _realtimePolylineNotifier,
                  builder: (context, points, child) {
                    if (points.isEmpty) return const SizedBox.shrink();
                    return PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          strokeWidth: 2.0,
                          color: Theme.of(context).colorScheme.primary.withAlpha((0.7 * 255).round()),
                        ),
                      ],
                    );
                  },
                ),

                // Marcador de ubicación actual (fast updates using ValueNotifier)
                ValueListenableBuilder<LatLng?>(
                  valueListenable: _markerNotifier,
                  builder: (context, markerPos, child) {
                    if (markerPos == null) return const SizedBox.shrink();
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: markerPos,
                          width: 20,
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _trackingData.isTracking 
                        ? (_trackingData.isPaused ? Colors.orange : Theme.of(context).colorScheme.primary)
                                    : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 2),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                  ],
                ),

                // Overlay: botón para centrar en la posición actual
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton(
                    mini: true,
                    onPressed: () async {
                      final loc = await _locationService.getCurrentLocation();
                      if (loc != null && _isMapReady) {
                        // permitir recentrar y restablecer flag de interacción
                        setState(() {
                          _userInteracted = false;
                        });
                        _mapController.move(loc, 16.0);
                      } else {
                        _showSnackBar('Ubicación no disponible', Theme.of(context).colorScheme.error);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),

                // Overlay: brújula dinámica (N giratoria)
                Positioned(
                  right: 12,
                  top: 12,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: _mapRotation),
                    duration: const Duration(milliseconds: 250),
                    builder: (context, value, child) {
                      // Rotamos en sentido contrario para que la N apunte al norte real
                      final angleRad = -value * (math.pi / 180.0);
                      return Transform.rotate(
                        angle: angleRad,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withAlpha((0.9 * 255).round()),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4),
                        ],
                      ),
                      child: const Text('N', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Panel de métricas
          MetricsPanel(
            trackingData: _trackingData,
            userSettings: _userSettings,
          ),
          
          // Controles de tracking
          TrackingControls(
            isTracking: _trackingData.isTracking,
            isPaused: _trackingData.isPaused,
            onStart: _startTracking,
            onPause: _pauseTracking,
            onResume: _resumeTracking,
            onStop: _stopTracking,
          ),
        ],
      ),
      
    );
  }
}