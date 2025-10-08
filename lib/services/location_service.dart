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

  // Stream controller para notificar cambios
  final StreamController<LiveTrackingData> _trackingController =
      StreamController<LiveTrackingData>.broadcast();

  Stream<LiveTrackingData> get trackingStream => _trackingController.stream;

  LiveTrackingData _currentData = LiveTrackingData();

  // Settings para modo 'tiempo real' (actualizaciones frecuentes)
  final LocationSettings _realTimeLocationSettings = const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );

  // Filtro de suavizado (low-pass) para reducir jitter
  LatLng? _lastFilteredLocation;
  final double _smoothingFactor = 0.20;
  final double _maxPlausibleSpeedKmh = 60.0; // km/h
  final double _minDistanceKmToAdd = 0.003; // ~3 m
  final double _maxAllowedAccuracyMeters = 30.0;

  LiveTrackingData get currentData => _currentData;

  // Verificar y solicitar permisos de ubicación
  Future<bool> checkAndRequestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<bool> startTracking() async {
    if (_currentData.isTracking) return true;

    final hasPermission = await checkAndRequestPermissions();
    if (!hasPermission) return false;

    try {
      final position = await Geolocator.getCurrentPosition();
      _lastFilteredLocation = LatLng(position.latitude, position.longitude);

      _currentData = _currentData.copyWith(
        isTracking: true,
        isPaused: false,
        startTime: DateTime.now(),
        lastUpdateTime: DateTime.now(),
        currentLocation: LatLng(position.latitude, position.longitude),
        routePoints: [LatLng(position.latitude, position.longitude)],
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: _realTimeLocationSettings,
      ).listen(_onLocationUpdate);

      _trackingTimer = Timer.periodic(const Duration(seconds: 1), _onTimerUpdate);

      _trackingController.add(_currentData);
      return true;
    } catch (e) {
      return false;
    }
  }

  void pauseTracking() {
    if (!_currentData.isTracking || _currentData.isPaused) return;
    _currentData = _currentData.copyWith(isPaused: true, pauseStartTime: DateTime.now());
    _trackingController.add(_currentData);
  }

  void resumeTracking() {
    if (!_currentData.isTracking || !_currentData.isPaused) return;
    Duration additionalPausedTime = Duration.zero;
    if (_currentData.pauseStartTime != null) {
      additionalPausedTime = DateTime.now().difference(_currentData.pauseStartTime!);
    }
    _currentData = _currentData.copyWith(
      isPaused: false,
      pauseStartTime: null,
      totalPausedTime: _currentData.totalPausedTime + additionalPausedTime,
    );
    _trackingController.add(_currentData);
  }

  void stopTracking() {
    _positionStream?.cancel();
    _trackingTimer?.cancel();
    _currentData = _currentData.copyWith(isTracking: false, isPaused: false);
    _trackingController.add(_currentData);
  }

  void resetTracking() {
    stopTracking();
    _currentData = LiveTrackingData();
    _trackingController.add(_currentData);
  }

  void _onLocationUpdate(Position position) {
    if (_currentData.isPaused || !_currentData.isTracking) return;
    final rawLocation = LatLng(position.latitude, position.longitude);
    final currentTime = DateTime.now();

    final accuracyMeters = position.accuracy;
    if (accuracyMeters > _maxAllowedAccuracyMeters) return;

    LatLng filteredLocation;
    if (_lastFilteredLocation == null) {
      filteredLocation = rawLocation;
    } else {
      final lat = (_smoothingFactor * rawLocation.latitude) + ((1 - _smoothingFactor) * _lastFilteredLocation!.latitude);
      final lon = (_smoothingFactor * rawLocation.longitude) + ((1 - _smoothingFactor) * _lastFilteredLocation!.longitude);
      filteredLocation = LatLng(lat, lon);
    }
    _lastFilteredLocation = filteredLocation;

    final currentSpeedKmhReported = (position.speed * 3.6).clamp(0.0, 200.0);
    final isSpeedImplausible = currentSpeedKmhReported > _maxPlausibleSpeedKmh;

    double newDistance = _currentData.distanceKm;
    if (_currentData.routePoints.isNotEmpty) {
      final lastPoint = _currentData.routePoints.last;
      final distance = _calculateDistance(lastPoint.latitude, lastPoint.longitude, filteredLocation.latitude, filteredLocation.longitude);
      final timeDeltaSeconds = max(1, currentTime.difference(_currentData.lastUpdateTime ?? currentTime).inSeconds);
      final impliedSpeedKmh = (distance / (timeDeltaSeconds / 3600.0));
      final isImpliedSpeedImplausible = impliedSpeedKmh > _maxPlausibleSpeedKmh;
      if (!isSpeedImplausible && !isImpliedSpeedImplausible && distance >= _minDistanceKmToAdd) {
        newDistance += distance;
      }
    }

    final newSpeeds = List<double>.from(_currentData.speeds);
    double speedToAdd = currentSpeedKmhReported;
    if (isSpeedImplausible) {
      final lastPoint = _currentData.routePoints.isNotEmpty ? _currentData.routePoints.last : null;
      if (lastPoint != null) {
        final lastTime = _currentData.lastUpdateTime ?? currentTime;
        final dt = max(1, currentTime.difference(lastTime).inSeconds);
        final distKm = _calculateDistance(lastPoint.latitude, lastPoint.longitude, filteredLocation.latitude, filteredLocation.longitude);
        final estimatedKmh = (distKm / (dt / 3600.0));
        speedToAdd = estimatedKmh.clamp(0.0, _maxPlausibleSpeedKmh);
      } else {
        speedToAdd = 0.0;
      }
    }
    newSpeeds.add(speedToAdd);

    final filteredSpeedsForAvg = newSpeeds.where((s) => s >= 0.5 && s <= _maxPlausibleSpeedKmh).toList();
    final averageSpeed = filteredSpeedsForAvg.isEmpty ? 0.0 : filteredSpeedsForAvg.reduce((a, b) => a + b) / filteredSpeedsForAvg.length;
    final maxSpeed = newSpeeds.isEmpty ? speedToAdd : max(_currentData.maxSpeedKmh, speedToAdd);

    final newRoutePoints = List<LatLng>.from(_currentData.routePoints);
    if (_currentData.routePoints.isEmpty || _calculateDistance(_currentData.routePoints.last.latitude, _currentData.routePoints.last.longitude, filteredLocation.latitude, filteredLocation.longitude) > 0.005) {
      newRoutePoints.add(filteredLocation);
    }

    _currentData = _currentData.copyWith(
      currentLocation: filteredLocation,
      currentSpeedKmh: speedToAdd,
      averageSpeedKmh: averageSpeed,
      maxSpeedKmh: maxSpeed,
      distanceKm: newDistance,
      routePoints: newRoutePoints,
      speeds: newSpeeds,
      lastUpdateTime: currentTime,
    );

    _trackingController.add(_currentData);
  }

  void _onTimerUpdate(Timer timer) {
    if (!_currentData.isTracking || _currentData.startTime == null) return;

    final now = DateTime.now();
    Duration totalElapsed = now.difference(_currentData.startTime!);
    Duration currentPauseTime = Duration.zero;
    if (_currentData.isPaused && _currentData.pauseStartTime != null) {
      currentPauseTime = now.difference(_currentData.pauseStartTime!);
    }
    final realElapsed = totalElapsed - _currentData.totalPausedTime - currentPauseTime;
    _currentData = _currentData.copyWith(elapsedTime: realElapsed);
    _trackingController.add(_currentData);
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

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

  void dispose() {
    _positionStream?.cancel();
    _trackingTimer?.cancel();
    _trackingController.close();
  }
}