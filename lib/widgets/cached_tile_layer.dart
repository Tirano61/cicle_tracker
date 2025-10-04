import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/map_cache_service.dart';

class CachedTileLayer extends StatelessWidget {
  final MapCacheService cacheService = MapCacheService();
  final String urlTemplate;
  final String userAgentPackageName;

  CachedTileLayer({
    super.key,
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    required this.userAgentPackageName,
  });

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: userAgentPackageName,
      tileBuilder: (context, widget, tile) {
        // Extraer coordenadas del tile
        final tileCoords = tile.coordinates;
        
        return FutureBuilder<String?>(
          future: cacheService.getCachedTilePath(
            tileCoords.x.toInt(),
            tileCoords.y.toInt(),
            tileCoords.z.toInt(),
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              // Usar tile cacheado
              final file = File(snapshot.data!);
              return Stack(
                children: [
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: 256,
                    height: 256,
                    errorBuilder: (context, error, stackTrace) {
                      // Si falla el archivo local, usar widget original
                      return widget;
                    },
                  ),
                  // Indicador de tile cacheado (opcional, para debug)
                  /*
                  const Positioned(
                    top: 2,
                    right: 2,
                    child: Icon(
                      Icons.wifi_off,
                      size: 12,
                      color: Colors.green,
                    ),
                  ),
                  */
                ],
              );
            } else {
              // Usar widget original de flutter_map
              return widget;
            }
          },
        );
      },
    );
  }
}