import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../models/live_tracking_data.dart';
import 'package:provider/provider.dart';
import '../controllers/tracking_controller.dart';
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
  // calorie calculator is handled by TrackingController
  late final TrackingController _trackingController;
  final MapController _mapController = MapController();
  // Note: marker/polyline notifiers are provided by TrackingController
  int? _sessionMaxZoom;
  StreamSubscription<int?>? _sessionZoomSub;
  bool _userInteracted = false; // true cuando el usuario ha hecho pan/zoom manual
  double _mapRotation = 0.0; // grados
  double _currentHeading = 0.0; // grados - del GPS
  double _lastValidHeading = 0.0; // para mantener último heading válido
  DateTime? _lastZoomWarning;
  final Duration _zoomWarnInterval = const Duration(seconds: 3);
  // Map recenter control removed; controller handles movement decisions
  late LiveTrackingData _trackingData;
  // Listener references so we can remove them on dispose
  VoidCallback? _markerListener;
  VoidCallback? _metricsListener;
  UserSettings _userSettings = UserSettings();
  // Animated marker state to smooth visual jumps
  LatLng? _markerAnimatedPos;
  Timer? _markerAnimationTimer;
  Duration _markerAnimationDuration = const Duration(milliseconds: 300);
  LatLng? _markerAnimationFrom;
  LatLng? _markerAnimationTo;
  MapTileProvider _currentMapProvider = MapTileProvider.openStreetMap;
  bool _isMapReady = false;
  // calorie timers handled by TrackingController

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _initializeLocation();
    // Obtain the shared TrackingController provided by the app (main.dart)
    _trackingController = Provider.of<TrackingController>(context, listen: false);
    // Not starting automatically; start on user action (same behavior previous start button used)
    // Hook controller notifiers to update UI-local animations
    // Initialize local tracking data from controller
    _trackingData = _trackingController.metricsNotifier.value;

    _markerListener = () {
      final pos = _trackingController.markerNotifier.value;
      if (pos != null) _animateMarkerTo(pos);
    };
    _metricsListener = () {
      _trackingData = _trackingController.metricsNotifier.value;
      
      // Actualizar heading desde el GPS
      if (_trackingData.currentHeading != null) {
        final newHeading = _trackingData.currentHeading!;
        // Debug: Log del heading recibido
        print('📡 GPS Heading updated: $newHeading° (previous: $_currentHeading°)');
        
        setState(() {
          _lastValidHeading = _currentHeading;
          _currentHeading = newHeading;
        });
      }
      
      if (mounted) setState(() {});
    };
    _trackingController.markerNotifier.addListener(_markerListener!);
    _trackingController.metricsNotifier.addListener(_metricsListener!);

    // Escuchar cambios en el session max zoom
    _sessionZoomSub = MapCacheService().sessionZoomStream.listen((z) {
      setState(() {
        _sessionMaxZoom = z;
      });
    });
  }

  @override
  void dispose() {
    if (_markerListener != null) {
      _trackingController.markerNotifier.removeListener(_markerListener!);
    }
    if (_metricsListener != null) {
      _trackingController.metricsNotifier.removeListener(_metricsListener!);
    }
    // controller is provided at app level; do not dispose it here
    super.dispose();
  }

  void _animateMarkerTo(LatLng target) {
    // Cancel previous
    _markerAnimationTimer?.cancel();

  final from = _markerAnimatedPos ?? _trackingController.markerNotifier.value ?? _trackingData.currentLocation;
    if (from == null) {
      // Direct set
  _markerAnimatedPos = target;
  setState(() {});
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
  // update local UI state only
  if (mounted) setState(() {});
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

  // Note: controller disposed in earlier dispose(); cleanup local animations below
  @override
  void deactivate() {
    _markerAnimationTimer?.cancel();
    _locationService.dispose();
    _sessionZoomSub?.cancel();
    super.deactivate();
  }

  Future<void> _loadUserSettings() async {
    final settings = await _preferencesService.loadUserSettings();
    final mapProvider = await _preferencesService.getMapProvider();
    if (!mounted) return;
    setState(() {
      _userSettings = settings;
      _currentMapProvider = mapProvider;
    });
    // Pass weight to tracking controller
    try {
      _trackingController.setWeightKg(_userSettings.weightKg);
    } catch (_) {}
  }

  Future<void> _initializeLocation() async {
    final currentLocation = await _locationService.getCurrentLocation();
    if (currentLocation != null && _isMapReady && !_userInteracted) {
      _mapController.move(currentLocation, 16.0);
    }
  }

  // Tracking controller now processes the location stream. We hook the
  // controller notifiers to update UI-specific animations/notifiers.

  Future<void> _startTracking() async {
    final success = await _trackingController.start();
    if (!success) {
      _showErrorDialog('Error de GPS', 'No se pudo acceder al GPS. Verifica que los permisos estén habilitados.');
      return;
    }

    if (!mounted) return;
    _showSnackBar('¡Tracking iniciado!', Theme.of(context).colorScheme.primary);
  }

  void _pauseTracking() {
    _trackingController.pause();
    _showSnackBar('Tracking pausado', Theme.of(context).colorScheme.secondary);
  }

  void _resumeTracking() {
    _trackingController.resume();
    _showSnackBar('Tracking reanudado', Theme.of(context).colorScheme.primary);
  }

  Future<void> _stopTracking() async {
    _trackingController.stop();

    // Guardar sesión si hay datos válidos (leer desde controller.metricsNotifier)
    final metrics = _trackingController.metricsNotifier.value;
    if (metrics.distanceKm > 0.1 && metrics.elapsedTime.inMinutes > 1) {
      await _saveSession();
      if (!mounted) return;
      _showSnackBar('¡Sesión guardada!', Theme.of(context).colorScheme.primary);
    }

    _locationService.resetTracking();
    if (!mounted) return;
    _showSnackBar('Tracking detenido', Theme.of(context).colorScheme.error);
  }

  

  // Calorie calculation and recalc are handled by TrackingController now.

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

  Widget _buildCompassBar(double rotation) {
    // Debug: Log de rotación recibida
    print('🧭 CompassBar - Rotation received: $rotation degrees');
    
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: rotation),
      duration: const Duration(milliseconds: 250),
      builder: (context, value, child) {
        // Debug: Log de rotación animada
        print('🎬 CompassBar - Animated rotation: $value degrees');
        
        return Container(
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withAlpha((0.95 * 255).round()),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: CustomPaint(
              painter: CompassBarPainter(
                rotation: value,
                primaryColor: Theme.of(context).colorScheme.primary,
                surfaceColor: Theme.of(context).colorScheme.surface,
                onSurfaceColor: Theme.of(context).colorScheme.onSurface,
              ),
              child: Container(),
            ),
          ),
        );
      },
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
                        // Debug: Log de rotación del mapa
                        print('🗺️ Map rotation changed: $rot degrees (previous: $_mapRotation)');
                        setState(() {
                          _mapRotation = rot;
                        });
                      } catch (e) {
                        // Debug: Log si no hay rotación disponible
                        print('⚠️ Map rotation not available: $e');
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
                  valueListenable: _trackingController.polylineFullNotifier,
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
                  valueListenable: _trackingController.polylineRealtimeNotifier,
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
                  valueListenable: _trackingController.markerNotifier,
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

                // Overlay: barra de puntos cardinales con indicador central
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: _buildCompassBar(_currentHeading),
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

/// Custom painter para la barra de brújula con puntos cardinales
class CompassBarPainter extends CustomPainter {
  final double rotation;
  final Color primaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;

  CompassBarPainter({
    required this.rotation,
    required this.primaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Debug: Log del painter
    print('🎨 CompassBarPainter - paint() called with rotation: $rotation degrees');
    
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    // Dimensiones
    final center = Offset(size.width / 2, size.height / 2);
    final barWidth = size.width * 0.8;
    final barHeight = size.height * 0.6;
    final barTop = (size.height - barHeight) / 2;
    
    // Puntos cardinales y sus posiciones angulares (0° = Norte)
    final cardinalPoints = [
      {'label': 'N', 'angle': 0.0},
      {'label': 'NE', 'angle': 45.0},
      {'label': 'E', 'angle': 90.0},
      {'label': 'SE', 'angle': 135.0},
      {'label': 'S', 'angle': 180.0},
      {'label': 'SW', 'angle': 225.0},
      {'label': 'W', 'angle': 270.0},
      {'label': 'NW', 'angle': 315.0},
    ];

    // Normalizar rotación para que esté entre 0-360
    var normalizedRotation = rotation % 360;
    if (normalizedRotation < 0) normalizedRotation += 360;
    
    // Debug: Log de rotación normalizada
    print('📐 CompassBarPainter - Normalized rotation: $normalizedRotation degrees');

    // Dibujar la barra de fondo
    paint.color = surfaceColor;
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH((size.width - barWidth) / 2, barTop, barWidth, barHeight),
      const Radius.circular(15),
    );
    canvas.drawRRect(barRect, paint);

    // Dibujar marcas menores cada 15 grados
    paint.color = onSurfaceColor.withOpacity(0.3);
    for (int i = 0; i < 360; i += 15) {
      final angleFromNorth = (i - normalizedRotation) % 360;
      if (angleFromNorth > 180) continue; // Solo dibujar las marcas visibles
      
      final x = center.dx + (angleFromNorth - 180) * (barWidth / 360);
      if (x >= (size.width - barWidth) / 2 && x <= (size.width + barWidth) / 2) {
        canvas.drawLine(
          Offset(x, barTop + barHeight * 0.7),
          Offset(x, barTop + barHeight * 0.9),
          paint,
        );
      }
    }

    // Dibujar puntos cardinales
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    
    // Debug: Log de inicio de dibujo de puntos cardinales
    print('🧭 Drawing cardinal points...');
    
    for (final point in cardinalPoints) {
      final angle = point['angle'] as double;
      final label = point['label'] as String;
      
      // Calcular posición relativa al centro de la barra
      final angleFromNorth = (angle - normalizedRotation) % 360;
      var displayAngle = angleFromNorth;
      if (displayAngle > 180) displayAngle -= 360;
      
      // Debug: Log de cálculo de ángulo para cada punto cardinal
      print('  📍 Point $label: angle=$angle°, angleFromNorth=$angleFromNorth°, displayAngle=$displayAngle°');
      
      // Solo mostrar puntos cardinales que están en el rango visible (-90 a +90 grados)
      if (displayAngle >= -90 && displayAngle <= 90) {
        final x = center.dx + displayAngle * (barWidth / 180);
        
        // Determinar si este punto cardinal está "activo" (cerca del centro)
        final isActive = displayAngle.abs() <= 22.5; // ±22.5 grados del centro
        
        // Debug: Log de punto visible
        print('    ✅ $label visible at x=$x, isActive=$isActive');
        
        // Color del texto
        paint.color = isActive ? primaryColor : onSurfaceColor;
        
        // Dibujar marca principal
        canvas.drawLine(
          Offset(x, barTop + barHeight * 0.3),
          Offset(x, barTop + barHeight * 0.7),
          paint..strokeWidth = isActive ? 3 : 2,
        );
        
        // Dibujar texto del punto cardinal
        textPainter.text = TextSpan(
          text: label,
          style: TextStyle(
            color: isActive ? primaryColor : onSurfaceColor,
            fontSize: isActive ? 14 : 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        );
        textPainter.layout();
        
        final textX = x - textPainter.width / 2;
        final textY = barTop + barHeight * 0.05;
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }

    // Dibujar indicador central (flecha apuntando hacia donde vamos)
    paint.color = primaryColor;
    paint.style = PaintingStyle.fill;
    
    final indicatorPath = ui.Path();
    final indicatorSize = 8.0;
    final indicatorY = barTop + barHeight * 0.5;
    
    // Flecha triangular apuntando hacia abajo
    indicatorPath.moveTo(center.dx, indicatorY + indicatorSize);
    indicatorPath.lineTo(center.dx - indicatorSize / 2, indicatorY - indicatorSize / 2);
    indicatorPath.lineTo(center.dx + indicatorSize / 2, indicatorY - indicatorSize / 2);
    indicatorPath.close();
    
    canvas.drawPath(indicatorPath, paint);
    
    // Línea central de referencia
    paint.strokeWidth = 2;
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx, barTop + barHeight * 0.75),
      Offset(center.dx, barTop + barHeight * 0.95),
      paint,
    );
  }

  @override
  bool shouldRepaint(CompassBarPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
           oldDelegate.primaryColor != primaryColor ||
           oldDelegate.surfaceColor != surfaceColor ||
           oldDelegate.onSurfaceColor != onSurfaceColor;
  }
}