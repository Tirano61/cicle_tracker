import 'dart:math';
import 'package:latlong2/latlong.dart';

class MapArea {
  final String id;
  final String name;
  final LatLng northEast;
  final LatLng southWest;
  final int minZoom;
  final int maxZoom;
  final DateTime? downloadedAt;
  final int totalTiles;
  final int downloadedTiles;
  final double sizeInMB;
  final bool isDownloading;

  MapArea({
    required this.id,
    required this.name,
    required this.northEast,
    required this.southWest,
    this.minZoom = 10,
    this.maxZoom = 18,
    this.downloadedAt,
    this.totalTiles = 0,
    this.downloadedTiles = 0,
    this.sizeInMB = 0.0,
    this.isDownloading = false,
  });

  // Verificar si está completamente descargada
  bool get isFullyDownloaded => downloadedTiles > 0 && downloadedTiles == totalTiles && downloadedAt != null;

  // Porcentaje de descarga
  double get downloadProgress => totalTiles > 0 ? (downloadedTiles / totalTiles) : 0.0;

  // Verificar si un punto está dentro de esta área
  bool containsPoint(LatLng point) {
    return point.latitude >= southWest.latitude &&
           point.latitude <= northEast.latitude &&
           point.longitude >= southWest.longitude &&
           point.longitude <= northEast.longitude;
  }

  // Calcular número total de tiles para el área y zooms especificados
  int calculateTotalTiles() {
    int total = 0;
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tilesAtZoom = _getTilesForZoomLevel(zoom);
      total += tilesAtZoom;
    }
    return total;
  }

  int _getTilesForZoomLevel(int zoom) {
    final scale = 1 << zoom; // 2^zoom
    
    final x1 = ((southWest.longitude + 180.0) / 360.0 * scale).floor();
    final x2 = ((northEast.longitude + 180.0) / 360.0 * scale).floor();
    
    final lat1Rad = southWest.latitude * (pi / 180.0);
    final lat2Rad = northEast.latitude * (pi / 180.0);
    
    final y1 = ((1.0 - log(tan(lat1Rad) + (1.0 / cos(lat1Rad)))) / pi / 2.0 + 0.5) * scale;
    final y2 = ((1.0 - log(tan(lat2Rad) + (1.0 / cos(lat2Rad)))) / pi / 2.0 + 0.5) * scale;
    
    final tilesX = (x2 - x1 + 1).abs();
    final tilesY = (y1.floor() - y2.floor() + 1).abs();
    
    return tilesX * tilesY;
  }

  // Convertir a Map para almacenamiento
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'northEastLat': northEast.latitude,
      'northEastLng': northEast.longitude,
      'southWestLat': southWest.latitude,
      'southWestLng': southWest.longitude,
      'minZoom': minZoom,
      'maxZoom': maxZoom,
      'downloadedAt': downloadedAt?.millisecondsSinceEpoch,
      'totalTiles': totalTiles,
      'downloadedTiles': downloadedTiles,
      'sizeInMB': sizeInMB,
      'isDownloading': isDownloading ? 1 : 0,
    };
  }

  // Crear desde Map
  factory MapArea.fromMap(Map<String, dynamic> map) {
    return MapArea(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      northEast: LatLng(
        map['northEastLat']?.toDouble() ?? 0.0,
        map['northEastLng']?.toDouble() ?? 0.0,
      ),
      southWest: LatLng(
        map['southWestLat']?.toDouble() ?? 0.0,
        map['southWestLng']?.toDouble() ?? 0.0,
      ),
      minZoom: map['minZoom'] ?? 10,
      maxZoom: map['maxZoom'] ?? 18,
      downloadedAt: map['downloadedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['downloadedAt'])
          : null,
      totalTiles: map['totalTiles'] ?? 0,
      downloadedTiles: map['downloadedTiles'] ?? 0,
      sizeInMB: map['sizeInMB']?.toDouble() ?? 0.0,
      isDownloading: (map['isDownloading'] ?? 0) == 1,
    );
  }

  // Crear copia con cambios
  MapArea copyWith({
    String? id,
    String? name,
    LatLng? northEast,
    LatLng? southWest,
    int? minZoom,
    int? maxZoom,
    DateTime? downloadedAt,
    int? totalTiles,
    int? downloadedTiles,
    double? sizeInMB,
    bool? isDownloading,
  }) {
    return MapArea(
      id: id ?? this.id,
      name: name ?? this.name,
      northEast: northEast ?? this.northEast,
      southWest: southWest ?? this.southWest,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      totalTiles: totalTiles ?? this.totalTiles,
      downloadedTiles: downloadedTiles ?? this.downloadedTiles,
      sizeInMB: sizeInMB ?? this.sizeInMB,
      isDownloading: isDownloading ?? this.isDownloading,
    );
  }

  @override
  String toString() {
    return 'MapArea{name: $name, progress: ${(downloadProgress * 100).toStringAsFixed(1)}%, size: ${sizeInMB.toStringAsFixed(1)}MB}';
  }
}