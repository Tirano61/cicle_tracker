import 'package:latlong2/latlong.dart';

class CyclingSession {
  final int? id;
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceKm;
  final double averageSpeedKmh;
  final double maxSpeedKmh;
  final double caloriesBurned;
  final Duration duration;
  final List<LatLng> routePoints;
  final List<double> speeds; // Velocidades registradas cada cierto tiempo
  final bool isCompleted;

  CyclingSession({
    this.id,
    required this.startTime,
    this.endTime,
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.maxSpeedKmh,
    required this.caloriesBurned,
    required this.duration,
    required this.routePoints,
    required this.speeds,
    this.isCompleted = false,
  });

  // Convertir a Map para almacenar en base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'distanceKm': distanceKm,
      'averageSpeedKmh': averageSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'caloriesBurned': caloriesBurned,
      'duration': duration.inMilliseconds,
      'routePoints': _routePointsToJson(routePoints),
      'speeds': speeds.join(','),
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  // Crear desde Map de base de datos
  factory CyclingSession.fromMap(Map<String, dynamic> map) {
    return CyclingSession(
      id: map['id'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime']),
      endTime: map['endTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime']) 
          : null,
      distanceKm: map['distanceKm']?.toDouble() ?? 0.0,
      averageSpeedKmh: map['averageSpeedKmh']?.toDouble() ?? 0.0,
      maxSpeedKmh: map['maxSpeedKmh']?.toDouble() ?? 0.0,
      caloriesBurned: map['caloriesBurned']?.toDouble() ?? 0.0,
      duration: Duration(milliseconds: map['duration'] ?? 0),
      routePoints: _routePointsFromJson(map['routePoints'] ?? ''),
      speeds: _speedsFromString(map['speeds'] ?? ''),
      isCompleted: (map['isCompleted'] ?? 0) == 1,
    );
  }

  // Helper para convertir puntos de ruta a JSON
  String _routePointsToJson(List<LatLng> points) {
    return points.map((point) => '${point.latitude},${point.longitude}').join(';');
  }

  // Helper para convertir JSON a puntos de ruta
  static List<LatLng> _routePointsFromJson(String json) {
    if (json.isEmpty) return [];
    
    return json.split(';').map((pointStr) {
      final coords = pointStr.split(',');
      if (coords.length == 2) {
        return LatLng(
          double.parse(coords[0]), 
          double.parse(coords[1])
        );
      }
      return LatLng(0, 0); // Punto por defecto en caso de error
    }).toList();
  }

  // Helper para convertir velocidades desde string
  static List<double> _speedsFromString(String speeds) {
    if (speeds.isEmpty) return [];
    
    return speeds.split(',').map((speed) {
      try {
        return double.parse(speed);
      } catch (e) {
        return 0.0;
      }
    }).toList();
  }

  // Crear copia con cambios
  CyclingSession copyWith({
    int? id,
    DateTime? startTime,
    DateTime? endTime,
    double? distanceKm,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    double? caloriesBurned,
    Duration? duration,
    List<LatLng>? routePoints,
    List<double>? speeds,
    bool? isCompleted,
  }) {
    return CyclingSession(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      distanceKm: distanceKm ?? this.distanceKm,
      averageSpeedKmh: averageSpeedKmh ?? this.averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      duration: duration ?? this.duration,
      routePoints: routePoints ?? this.routePoints,
      speeds: speeds ?? this.speeds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  String toString() {
    return 'CyclingSession{id: $id, distanceKm: $distanceKm, averageSpeedKmh: $averageSpeedKmh, duration: $duration}';
  }
}