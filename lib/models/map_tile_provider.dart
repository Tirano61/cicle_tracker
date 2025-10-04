import 'package:flutter/material.dart';

enum MapTileProvider {
  openStreetMap,
  cartoDark,
  esriSatellite;

  String get name {
    switch (this) {
      case MapTileProvider.openStreetMap:
        return 'Estándar';
      case MapTileProvider.cartoDark:
        return 'Voyager';
      case MapTileProvider.esriSatellite:
        return 'Satélite';
    }
  }

  String get description {
    switch (this) {
      case MapTileProvider.openStreetMap:
        return 'Mapa clásico de calles';
      case MapTileProvider.cartoDark:
        return 'Tema elegante con colores suaves';
      case MapTileProvider.esriSatellite:
        return 'Imágenes satelitales';
    }
  }

  String get urlTemplate {
    switch (this) {
      case MapTileProvider.openStreetMap:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapTileProvider.cartoDark:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';
      case MapTileProvider.esriSatellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    }
  }

  List<String> get subdomains {
    switch (this) {
      case MapTileProvider.openStreetMap:
        return ['a', 'b', 'c'];
      case MapTileProvider.cartoDark:
        return ['a', 'b', 'c', 'd'];
      case MapTileProvider.esriSatellite:
        return [];
    }
  }

  Map<String, String> get headers {
    switch (this) {
      case MapTileProvider.openStreetMap:
        return {'User-Agent': 'CycleTracker/1.0'};
      case MapTileProvider.cartoDark:
        return {'User-Agent': 'CycleTracker/1.0'};
      case MapTileProvider.esriSatellite:
        return {
          'User-Agent': 'CycleTracker/1.0',
          'Referer': 'https://www.arcgis.com'
        };
    }
  }

  String get attribution {
    switch (this) {
      case MapTileProvider.openStreetMap:
        return '© OpenStreetMap contributors';
      case MapTileProvider.cartoDark:
        return '© CARTO © OpenStreetMap contributors';
      case MapTileProvider.esriSatellite:
        return '© Esri, Maxar, Earthstar Geographics';
    }
  }

  IconData get icon {
    switch (this) {
      case MapTileProvider.openStreetMap:
        return Icons.map;
      case MapTileProvider.cartoDark:
        return Icons.palette;
      case MapTileProvider.esriSatellite:
        return Icons.satellite_alt;
    }
  }
}