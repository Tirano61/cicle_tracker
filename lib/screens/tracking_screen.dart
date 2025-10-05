import 'dart:async';
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

  StreamSubscription<LiveTrackingData>? _trackingSubscription;
  
  LiveTrackingData _trackingData = LiveTrackingData();
  UserSettings _userSettings = UserSettings();
  MapTileProvider _currentMapProvider = MapTileProvider.openStreetMap;
  bool _isMapReady = false;
  Timer? _calorieTimer;
  Timer? _recalculateTimer;

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
    _initializeLocation();
    _listenToTracking();
  }

  @override
  void dispose() {
    _trackingSubscription?.cancel();
    _calorieTimer?.cancel();
    _recalculateTimer?.cancel();
    _locationService.dispose();
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
    if (currentLocation != null && _isMapReady) {
      _mapController.move(currentLocation, 16.0);
    }
  }

  void _listenToTracking() {
    _trackingSubscription = _locationService.trackingStream.listen((data) {
      setState(() {
        _trackingData = data;
      });

      // Mover mapa a ubicación actual si está trackeando
      if (data.isTracking && data.currentLocation != null && _isMapReady) {
        _mapController.move(data.currentLocation!, 16.0);
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

    // Usar el método mejorado que funciona mejor con datos limitados del GPS
    final intervalCalories = _calorieCalculator.estimateCaloriesForInterval(
      weightKg: _userSettings.weightKg,
      recentSpeeds: _trackingData.speeds,
      intervalSeconds: 5, // Actualización cada 5 segundos
      currentSpeedKmh: _trackingData.currentSpeedKmh > 1.0 
          ? _trackingData.currentSpeedKmh 
          : null,
    );

    final newCalories = _trackingData.caloriesBurned + intervalCalories;

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
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: const LatLng(40.7128, -74.0060), // Nueva York por defecto
                initialZoom: 16.0,
                onMapReady: () {
                  _isMapReady = true;
                  _initializeLocation();
                },
              ),
              children: [
                CachedTileLayer(
                  tileProvider: _currentMapProvider,
                  userAgentPackageName: 'com.example.cicle_app',
                ),
                // Ruta recorrida
                if (_trackingData.routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _trackingData.routePoints,
                        strokeWidth: 4.0,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                // Marcador de ubicación actual
                if (_trackingData.currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _trackingData.currentLocation!,
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