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
import 'history_screen.dart';
import 'settings_screen.dart';

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
  bool _isMapReady = false;
  Timer? _calorieTimer;

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
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _loadUserSettings() async {
    final settings = await _preferencesService.loadUserSettings();
    setState(() {
      _userSettings = settings;
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

    _showSnackBar('¡Tracking iniciado!', Colors.green);
  }

  void _pauseTracking() {
    _locationService.pauseTracking();
    _calorieTimer?.cancel();
    _showSnackBar('Tracking pausado', Colors.orange);
  }

  void _resumeTracking() {
    _locationService.resumeTracking();
    
    // Reiniciar timer de calorías
    _calorieTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_trackingData.isTracking && !_trackingData.isPaused) {
        _updateCalories();
      }
    });

    _showSnackBar('Tracking reanudado', Colors.green);
  }

  Future<void> _stopTracking() async {
    _locationService.stopTracking();
    _calorieTimer?.cancel();

    // Guardar sesión si hay datos válidos
    if (_trackingData.distanceKm > 0.1 && _trackingData.elapsedTime.inMinutes > 1) {
      await _saveSession();
      _showSnackBar('¡Sesión guardada!', Colors.blue);
    }

    _locationService.resetTracking();
    _showSnackBar('Tracking detenido', Colors.red);
  }

  void _updateCalories() {
    if (!_trackingData.isTracking || _trackingData.isPaused) return;

    final caloriesPerMinute = _calorieCalculator.calculateCaloriesPerMinute(
      weightKg: _userSettings.weightKg,
      currentSpeedKmh: _trackingData.currentSpeedKmh,
    );

    final newCalories = _trackingData.caloriesBurned + (caloriesPerMinute / 12); // 5 segundos

    setState(() {
      _trackingData = _trackingData.copyWith(caloriesBurned: newCalories);
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
          color: Colors.white.withOpacity(0.9),
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
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Indicador de estado de mapas
          _buildConnectionIndicator(),
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
                  userAgentPackageName: 'com.example.cicle_app',
                ),
                // Ruta recorrida
                if (_trackingData.routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _trackingData.routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
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
                                ? (_trackingData.isPaused ? Colors.orange : Colors.red)
                                : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
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