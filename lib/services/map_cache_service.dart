import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/map_area.dart';
import 'package:latlong2/latlong.dart';

class MapCacheService {
  static final MapCacheService _instance = MapCacheService._internal();
  factory MapCacheService() => _instance;
  MapCacheService._internal();

  static Database? _database;
  static String? _cacheDirectory;
  final Dio _dio = Dio();

  // OpenStreetMap tile server
  static const String tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // Stream para progreso de descarga
  final StreamController<MapArea> _downloadProgressController = 
      StreamController<MapArea>.broadcast();
  
  Stream<MapArea> get downloadProgress => _downloadProgressController.stream;

  // Configuración de cache
  static const int maxCacheSizeMB = 500; // 500MB máximo
  static const int defaultMaxZoom = 18;
  static const int defaultMinZoom = 10;

  // Inicializar el servicio
  Future<void> initialize() async {
    await _initializeDatabase();
    await _initializeCacheDirectory();
    _configureDio();
  }

  Future<void> _initializeDatabase() async {
    if (_database != null) return;

    final documentsPath = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsPath.path, 'map_cache.db');

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // Tabla para áreas de mapas
        await db.execute('''
          CREATE TABLE map_areas (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            northEastLat REAL NOT NULL,
            northEastLng REAL NOT NULL,
            southWestLat REAL NOT NULL,
            southWestLng REAL NOT NULL,
            minZoom INTEGER NOT NULL,
            maxZoom INTEGER NOT NULL,
            downloadedAt INTEGER,
            totalTiles INTEGER DEFAULT 0,
            downloadedTiles INTEGER DEFAULT 0,
            sizeInMB REAL DEFAULT 0.0,
            isDownloading INTEGER DEFAULT 0
          )
        ''');

        // Tabla para tiles individuales (metadata)
        await db.execute('''
          CREATE TABLE cached_tiles (
            id TEXT PRIMARY KEY,
            areaId TEXT,
            x INTEGER NOT NULL,
            y INTEGER NOT NULL,
            z INTEGER NOT NULL,
            filePath TEXT NOT NULL,
            downloadedAt INTEGER NOT NULL,
            sizeBytes INTEGER NOT NULL,
            FOREIGN KEY (areaId) REFERENCES map_areas (id) ON DELETE CASCADE
          )
        ''');

        await db.execute('CREATE INDEX idx_tiles_xyz ON cached_tiles(x, y, z)');
        await db.execute('CREATE INDEX idx_tiles_area ON cached_tiles(areaId)');
      },
    );
  }

  Future<void> _initializeCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDirectory = path.join(appDir.path, 'map_tiles');
    
    final cacheDir = Directory(_cacheDirectory!);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'CycleTracker/1.0',
      },
    );
  }

  // Crear nueva área para descargar
  Future<MapArea> createArea({
    required String name,
    required LatLng northEast,
    required LatLng southWest,
    int minZoom = defaultMinZoom,
    int maxZoom = defaultMaxZoom,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    
    final area = MapArea(
      id: id,
      name: name,
      northEast: northEast,
      southWest: southWest,
      minZoom: minZoom,
      maxZoom: maxZoom,
      totalTiles: 0,
    );

    final totalTiles = area.calculateTotalTiles();
    final updatedArea = area.copyWith(totalTiles: totalTiles);

    await _database!.insert('map_areas', updatedArea.toMap());
    return updatedArea;
  }

  // Obtener todas las áreas
  Future<List<MapArea>> getAllAreas() async {
    final maps = await _database!.query('map_areas', orderBy: 'name ASC');
    return maps.map((map) => MapArea.fromMap(map)).toList();
  }

  // Descargar área completa
  Future<void> downloadArea(String areaId) async {
    final areaMap = await _database!.query(
      'map_areas',
      where: 'id = ?',
      whereArgs: [areaId],
    );

    if (areaMap.isEmpty) return;

    MapArea area = MapArea.fromMap(areaMap.first);
    
    // Marcar como descargando
    area = area.copyWith(isDownloading: true, downloadedTiles: 0);
    await _updateAreaInDatabase(area);

    try {
      int downloadedCount = 0;
      double totalSize = 0.0;

      for (int zoom = area.minZoom; zoom <= area.maxZoom; zoom++) {
        final tiles = _getTilesForZoomLevel(area, zoom);
        
        for (final tile in tiles) {
          try {
            final size = await _downloadTile(tile['x']!, tile['y']!, zoom, areaId);
            if (size > 0) {
              totalSize += size / (1024 * 1024); // Convert to MB
              downloadedCount++;
              
              // Actualizar progreso cada 10 tiles
              if (downloadedCount % 10 == 0) {
                area = area.copyWith(
                  downloadedTiles: downloadedCount,
                  sizeInMB: totalSize,
                );
                await _updateAreaInDatabase(area);
                _downloadProgressController.add(area);
              }
            }
          } catch (e) {
            print('Error downloading tile ${tile['x']},${tile['y']},${zoom}: $e');
            // Continuar con el siguiente tile
          }
        }
      }

      // Marcar como completada
      area = area.copyWith(
        isDownloading: false,
        downloadedAt: DateTime.now(),
        downloadedTiles: downloadedCount,
        sizeInMB: totalSize,
      );

      await _updateAreaInDatabase(area);
      _downloadProgressController.add(area);

    } catch (e) {
      // Error en descarga, marcar como no descargando
      area = area.copyWith(isDownloading: false);
      await _updateAreaInDatabase(area);
      rethrow;
    }
  }

  // Descargar tile individual
  Future<int> _downloadTile(int x, int y, int z, String areaId) async {
    final tileId = '${z}_${x}_$y';
    
    // Verificar si ya existe
    final existingTiles = await _database!.query(
      'cached_tiles',
      where: 'x = ? AND y = ? AND z = ?',
      whereArgs: [x, y, z],
    );
    
    if (existingTiles.isNotEmpty) {
      return 0; // Ya descargado
    }

    final url = tileUrlTemplate
        .replaceAll('{z}', z.toString())
        .replaceAll('{x}', x.toString())
        .replaceAll('{y}', y.toString());

    final response = await _dio.get<Uint8List>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode == 200 && response.data != null) {
      final fileName = '${tileId}.png';
      final filePath = path.join(_cacheDirectory!, fileName);
      
      final file = File(filePath);
      await file.writeAsBytes(response.data!);
      
      // Guardar metadata en DB
      await _database!.insert('cached_tiles', {
        'id': tileId,
        'areaId': areaId,
        'x': x,
        'y': y,
        'z': z,
        'filePath': filePath,
        'downloadedAt': DateTime.now().millisecondsSinceEpoch,
        'sizeBytes': response.data!.length,
      });

      return response.data!.length;
    }

    return 0;
  }

  // Obtener tiles para un nivel de zoom específico
  List<Map<String, int>> _getTilesForZoomLevel(MapArea area, int zoom) {
    final tiles = <Map<String, int>>[];
    final scale = 1 << zoom;
    
    final x1 = ((area.southWest.longitude + 180.0) / 360.0 * scale).floor();
    final x2 = ((area.northEast.longitude + 180.0) / 360.0 * scale).floor();
    
    final lat1Rad = area.southWest.latitude * (pi / 180.0);
    final lat2Rad = area.northEast.latitude * (pi / 180.0);
    
    final y1 = ((1.0 - log(tan(lat1Rad) + (1.0 / cos(lat1Rad)))) / pi / 2.0 + 0.5) * scale;
    final y2 = ((1.0 - log(tan(lat2Rad) + (1.0 / cos(lat2Rad)))) / pi / 2.0 + 0.5) * scale;
    
    for (int x = x1; x <= x2; x++) {
      for (int y = y2.floor(); y <= y1.floor(); y++) {
        tiles.add({'x': x, 'y': y, 'z': zoom});
      }
    }
    
    return tiles;
  }

  // Verificar si un tile está disponible en cache
  Future<String?> getCachedTilePath(int x, int y, int z) async {
    final tiles = await _database!.query(
      'cached_tiles',
      where: 'x = ? AND y = ? AND z = ?',
      whereArgs: [x, y, z],
    );

    if (tiles.isNotEmpty) {
      final filePath = tiles.first['filePath'] as String;
      final file = File(filePath);
      
      if (await file.exists()) {
        return filePath;
      } else {
        // Archivo no existe, limpiar de DB
        await _database!.delete(
          'cached_tiles',
          where: 'x = ? AND y = ? AND z = ?',
          whereArgs: [x, y, z],
        );
      }
    }

    return null;
  }

  // Eliminar área y sus tiles
  Future<void> deleteArea(String areaId) async {
    // Obtener todos los tiles del área
    final tiles = await _database!.query(
      'cached_tiles',
      where: 'areaId = ?',
      whereArgs: [areaId],
    );

    // Eliminar archivos físicos
    for (final tile in tiles) {
      final filePath = tile['filePath'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Eliminar de base de datos
    await _database!.delete('cached_tiles', where: 'areaId = ?', whereArgs: [areaId]);
    await _database!.delete('map_areas', where: 'id = ?', whereArgs: [areaId]);
  }

  // Obtener tamaño total del cache
  Future<double> getTotalCacheSizeMB() async {
    final result = await _database!.rawQuery(
      'SELECT COALESCE(SUM(sizeInMB), 0) as totalSize FROM map_areas'
    );
    return (result.first['totalSize'] as num).toDouble();
  }

  // Limpiar cache viejo
  Future<void> cleanOldCache({int maxAgeInDays = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
    
    final oldTiles = await _database!.query(
      'cached_tiles',
      where: 'downloadedAt < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );

    for (final tile in oldTiles) {
      final filePath = tile['filePath'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _database!.delete(
      'cached_tiles',
      where: 'downloadedAt < ?',
      whereArgs: [cutoffDate.millisecondsSinceEpoch],
    );
  }

  Future<void> _updateAreaInDatabase(MapArea area) async {
    await _database!.update(
      'map_areas',
      area.toMap(),
      where: 'id = ?',
      whereArgs: [area.id],
    );
  }

  // Cerrar servicio
  Future<void> dispose() async {
    await _downloadProgressController.close();
    await _database?.close();
    _database = null;
  }
}