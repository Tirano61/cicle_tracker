import 'package:latlong2/latlong.dart';

class LiveTrackingData {
  final double currentSpeedKmh;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final double distanceKm;
  final Duration elapsedTime;
  final double caloriesBurned;
  final LatLng? currentLocation;
  final List<LatLng> routePoints;
  final List<double> speeds;
  final bool isTracking;
  final bool isPaused;
  final DateTime? startTime;
  final DateTime? lastUpdateTime;

  LiveTrackingData({
    this.currentSpeedKmh = 0.0,
    this.averageSpeedKmh = 0.0,
    this.maxSpeedKmh = 0.0,
    this.distanceKm = 0.0,
    this.elapsedTime = Duration.zero,
    this.caloriesBurned = 0.0,
    this.currentLocation,
    this.routePoints = const [],
    this.speeds = const [],
    this.isTracking = false,
    this.isPaused = false,
    this.startTime,
    this.lastUpdateTime,
  });

  // Crear copia con cambios
  LiveTrackingData copyWith({
    double? currentSpeedKmh,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    double? distanceKm,
    Duration? elapsedTime,
    double? caloriesBurned,
    LatLng? currentLocation,
    List<LatLng>? routePoints,
    List<double>? speeds,
    bool? isTracking,
    bool? isPaused,
    DateTime? startTime,
    DateTime? lastUpdateTime,
  }) {
    return LiveTrackingData(
      currentSpeedKmh: currentSpeedKmh ?? this.currentSpeedKmh,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      distanceKm: distanceKm ?? this.distanceKm,
      elapsedTime: elapsedTime ?? this.elapsedTime,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      currentLocation: currentLocation ?? this.currentLocation,
      routePoints: routePoints ?? this.routePoints,
      speeds: speeds ?? this.speeds,
      isTracking: isTracking ?? this.isTracking,
      isPaused: isPaused ?? this.isPaused,
      startTime: startTime ?? this.startTime,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  // Resetear todos los datos para nueva sesión
  LiveTrackingData reset() {
    return LiveTrackingData(
      currentSpeedKmh: 0.0,
      averageSpeedKmh: 0.0,
      maxSpeedKmh: 0.0,
      distanceKm: 0.0,
      elapsedTime: Duration.zero,
      caloriesBurned: 0.0,
      currentLocation: null,
      routePoints: [],
      speeds: [],
      isTracking: false,
      isPaused: false,
      startTime: null,
      lastUpdateTime: null,
    );
  }

  @override
  String toString() {
    return 'LiveTrackingData{currentSpeedKmh: $currentSpeedKmh, distanceKm: $distanceKm, elapsedTime: $elapsedTime, isTracking: $isTracking}';
  }
}