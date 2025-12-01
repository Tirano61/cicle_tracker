import 'package:latlong2/latlong.dart';
import 'dart:convert';

class ImportedRoute {
  final int? id;
  final String? name;
  final String? description;
  final String? gpxText;
  final List<LatLng> points;
  final double distanceKm;
  final DateTime createdAt;

  ImportedRoute({
    this.id,
    this.name,
    this.description,
    this.gpxText,
    required this.points,
    required this.distanceKm,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'gpx_text': gpxText,
      'route_points': jsonEncode(points.map((p) => [p.latitude, p.longitude]).toList()),
      'distance_km': distanceKm,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory ImportedRoute.fromMap(Map<String, dynamic> m) {
    final list = (jsonDecode(m['route_points']) as List).cast<List>();
    final points = list.map((e) => LatLng((e[0] as num).toDouble(), (e[1] as num).toDouble())).toList();
    return ImportedRoute(
      id: m['id'] as int?,
      name: m['name'] as String?,
      description: m['description'] as String?,
      gpxText: m['gpx_text'] as String?,
      points: points,
      distanceKm: (m['distance_km'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    );
  }
}
