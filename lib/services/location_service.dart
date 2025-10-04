import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/live_tracking_data.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _trackingTimer;
  
  // Stream controllers para notificar cambios
  final StreamController<LiveTrackingData> _trackingController =
      StreamController<LiveTrackingData>.broadcast();
  
  Stream<LiveTrackingData> get trackingStream => _trackingController.stream;

  LiveTrackingData _currentData = LiveTrackingData();
  
  // Configuración de precisión GPS
  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 3, // Actualizar cada 3 metros de movimiento
  );

  // Obtener datos actuales
  LiveTrackingData get currentData => _currentData;

  // Verificar y solicitar permisos de ubicación
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está habilitado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // Verificar permisos
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Iniciar tracking de GPS
  Future<bool> startTracking() async {
    if (_currentData.isTracking) return true;

    // Verificar permisos
    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return false;

    try {
      // Obtener ubicación inicial
      final position = await Geolocator.getCurrentPosition();
      
      _currentData = _currentData.copyWith(
        isTracking: true,
        isPaused: false,
        startTime: DateTime.now(),
        lastUpdateTime: DateTime.now(),
        currentLocation: LatLng(position.latitude, position.longitude),
        routePoints: [LatLng(position.latitude, position.longitude)],
      );

      // Iniciar stream de posición
      _positionStream = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(_onLocationUpdate);

      // Iniciar timer para actualizar tiempo transcurrido
      _trackingTimer = Timer.periodic(
        const Duration(seconds: 1),
        _onTimerUpdate,
      );

      _trackingController.add(_currentData);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Pausar tracking
  void pauseTracking() {
    if (!_currentData.isTracking || _currentData.isPaused) return;

    _currentData = _currentData.copyWith(isPaused: true);
    _trackingController.add(_currentData);
  }

  // Resumir tracking
  void resumeTracking() {
    if (!_currentData.isTracking || !_currentData.isPaused) return;

    _currentData = _currentData.copyWith(isPaused: false);
    _trackingController.add(_currentData);
  }

  // Detener tracking
  void stopTracking() {
    _positionStream?.cancel();
    _trackingTimer?.cancel();
    
    _currentData = _currentData.copyWith(
      isTracking: false,
      isPaused: false,
    );
    
    _trackingController.add(_currentData);
  }

  // Reset para nueva sesión
  void resetTracking() {
    stopTracking();
    _currentData = LiveTrackingData();
    _trackingController.add(_currentData);
  }

  // Callback cuando se actualiza la ubicación
  void _onLocationUpdate(Position position) {
    if (_currentData.isPaused || !_currentData.isTracking) return;

    final newLocation = LatLng(position.latitude, position.longitude);
    final currentTime = DateTime.now();
    
    // Calcular velocidad actual (m/s a km/h)
    final currentSpeedKmh = (position.speed * 3.6).clamp(0.0, 100.0);
    
    // Calcular distancia si hay puntos previos
    double newDistance = _currentData.distanceKm;
    if (_currentData.routePoints.isNotEmpty) {
      final lastPoint = _currentData.routePoints.last;
      final distance = _calculateDistance(
        lastPoint.latitude, lastPoint.longitude,
        newLocation.latitude, newLocation.longitude,
      );
      
      // Solo agregar si la distancia es significativa (más de 2 metros)
      if (distance > 0.002) {
        newDistance += distance;
      }
    }

    // Agregar nueva velocidad a la lista
    final newSpeeds = List<double>.from(_currentData.speeds);
    newSpeeds.add(currentSpeedKmh);

    // Calcular velocidad promedio
    final averageSpeed = newSpeeds.isEmpty 
        ? 0.0 
        : newSpeeds.reduce((a, b) => a + b) / newSpeeds.length;

    // Calcular velocidad máxima
    final maxSpeed = newSpeeds.isEmpty 
        ? currentSpeedKmh 
        : max(_currentData.maxSpeedKmh, currentSpeedKmh);

    // Agregar nuevo punto de ruta
    final newRoutePoints = List<LatLng>.from(_currentData.routePoints);
    if (_currentData.routePoints.isEmpty || 
        _calculateDistance(
          _currentData.routePoints.last.latitude,
          _currentData.routePoints.last.longitude,
          newLocation.latitude,
          newLocation.longitude,
        ) > 0.005) { // Agregar punto cada 5 metros aprox
      newRoutePoints.add(newLocation);
    }

    _currentData = _currentData.copyWith(
      currentLocation: newLocation,
      currentSpeedKmh: currentSpeedKmh,
      averageSpeedKmh: averageSpeed,
      maxSpeedKmh: maxSpeed,
      distanceKm: newDistance,
      routePoints: newRoutePoints,
      speeds: newSpeeds,
      lastUpdateTime: currentTime,
    );

    _trackingController.add(_currentData);
  }

  // Callback del timer para actualizar tiempo transcurrido
  void _onTimerUpdate(Timer timer) {
    if (!_currentData.isTracking || _currentData.startTime == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_currentData.startTime!);
    
    _currentData = _currentData.copyWith(elapsedTime: elapsed);
    _trackingController.add(_currentData);
  }

  // Calcular distancia entre dos puntos en km
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

  // Obtener ubicación actual sin iniciar tracking
  Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition();
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }

  // Limpiar recursos
  void dispose() {
    _positionStream?.cancel();
    _trackingTimer?.cancel();
    _trackingController.close();
  }
}