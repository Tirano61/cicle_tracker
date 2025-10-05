import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
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
  
  // Control de cancelación
  bool _isCancelled = false;
  // Indica que hay una descarga activa en curso
  bool _activeDownload = false;

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
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'CycleTracker/1.0 (+https://github.com/example/cycle-tracker)',
        'Accept': 'image/png,image/jpeg,image/*,*/*;q=0.8',
        'Accept-Encoding': 'gzip, deflate',
        'Cache-Control': 'no-cache',
      },
    );
    
    // Configurar interceptores para logging y retry
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Delay mínimo para WiFi rápido
        Future.delayed(Duration(milliseconds: Random().nextInt(20))).then((_) {
          handler.next(options);
        });
      },
      onError: (error, handler) {
    if (kDebugMode) debugPrint('HTTP Error: ${error.message}');
        handler.next(error);
      },
    ));
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
            if (kDebugMode) debugPrint('Error downloading tile ${tile['x']},${tile['y']},$zoom: $e');
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

  // Descargar tile individual con manejo mejorado de errores
  Future<int> _downloadTile(int x, int y, int z, String areaId, {bool forceDownload = false}) async {
  final tileId = '${z}_${x}_${y}';
    // Abort early if cancellation requested
    if (_isCancelled) return 0;
    // Verificar si ya existe
    if (!forceDownload) {
      final existingTiles = await _database!.query(
        'cached_tiles',
        where: 'x = ? AND y = ? AND z = ?',
        whereArgs: [x, y, z],
      );
      if (existingTiles.isNotEmpty) {
        // Verificar que el archivo físico existe
        final filePath = existingTiles.first['filePath'] as String;
        final file = File(filePath);
        if (await file.exists()) {
          return existingTiles.first['sizeBytes'] as int; // Ya descargado
        } else {
          // Archivo no existe, limpiar de DB y re-descargar
          await _database!.delete(
            'cached_tiles',
            where: 'x = ? AND y = ? AND z = ?',
            whereArgs: [x, y, z],
          );
        }
      }
    } else {
      // Forzar: eliminar metadata previa para re-descarga
      await _database!.delete(
        'cached_tiles',
        where: 'x = ? AND y = ? AND z = ?',
        whereArgs: [x, y, z],
      );
    }

  final url = tileUrlTemplate
    .replaceAll('{z}', z.toString())
    .replaceAll('{x}', x.toString())
    .replaceAll('{y}', y.toString());

    try {
  if (kDebugMode) debugPrint('Downloading tile URL: $url');
      final response = await _dio.get<Uint8List>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 45),
        ),
      );

      if (response.statusCode == 200 && response.data != null && response.data!.isNotEmpty) {
  // Guardar los tiles en subcarpetas por areaId y zoom para reducir archivos en una sola carpeta
  final fileName = '${x}_${y}.png';
        final dirPath = path.join(_cacheDirectory!, areaId, z.toString());
        final dir = Directory(dirPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        final filePath = path.join(dirPath, fileName);
        
        final file = File(filePath);
        await file.writeAsBytes(response.data!);
        
        // Verificar que el archivo se escribió correctamente
        if (await file.exists()) {
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
          }, conflictAlgorithm: ConflictAlgorithm.replace);

          return response.data!.length;
        } else {
          if (kDebugMode) debugPrint('File write failed for tile $x,$y,$z at $filePath');
        }
        } else {
  if (kDebugMode) debugPrint('Invalid response for tile $x,$y,$z: status=${response.statusCode}');
      }
    } catch (e) {
  if (kDebugMode) debugPrint('Network error downloading tile $x,$y,$z: $e');
      // Re-throw para que el retry handler lo maneje
      rethrow;
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

  // Descargar región específica por coordenadas (método optimizado sin bloquear UI)
  Future<void> downloadRegion(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int minZoom = defaultMinZoom,
    int maxZoom = defaultMaxZoom,
    /// onProgress: (processedTiles, totalTiles, newlyDownloadedTiles)
    Function(int processed, int total, int newDownloaded)? onProgress,
    bool forceDownload = false,
  }) async {
  // Resetear estado de cancelación y marcar descarga activa
  _resetCancellation();
  _activeDownload = true;

  // Usar batches más grandes para WiFi de alta velocidad y limitar concurrencia
  const int batchSize = 50; // tiles por batch
  const int concurrency = 6; // descargas paralelas por chunk

  // Crear área temporal
  final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

  int totalTiles = 0;
  int downloadedTiles = 0;
    
    // Calcular total de tiles y generar resumen por zoom
    final Map<int, int> perZoom = {};
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tiles = _getTilesForRegion(minLat, maxLat, minLng, maxLng, zoom);
      perZoom[zoom] = tiles.length;
      debugPrint('downloadRegion: zoom=$zoom tiles=${tiles.length}');
      totalTiles += tiles.length;
    }
    
  // Reportar progreso inicial (processed=0, total, newDownloaded=0)
  onProgress?.call(0, totalTiles, 0);
  debugPrint('downloadRegion: totalTiles=$totalTiles minZoom=$minZoom maxZoom=$maxZoom');

  // Si no hay tiles que descargar, abortar y loguear claramente
  if (totalTiles == 0) {
    debugPrint('downloadRegion: totalTiles == 0 -> nothing to download, exiting');
    _activeDownload = false;
    return;
  }

  // (moved: see class-level getTileCountsForRegion)
    
    // Descargar por nivel de zoom en batches
    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tiles = _getTilesForRegion(minLat, maxLat, minLng, maxLng, zoom);
  debugPrint('Processing zoom $zoom with ${tiles.length} tiles');
      
      // Dividir en batches para no bloquear la UI
      for (int i = 0; i < tiles.length; i += batchSize) {
        final endIndex = (i + batchSize < tiles.length) ? i + batchSize : tiles.length;
        final batch = tiles.sublist(i, endIndex);

        // Verificar si la descarga fue cancelada
        if (_isCancelled) {
          if (kDebugMode) debugPrint('Download cancelled by user');
          _activeDownload = false;
          return;
        }

        // Procesar el batch en chunks con concurrencia limitada
        for (int j = 0; j < batch.length; j += concurrency) {
          final chunkEnd = (j + concurrency < batch.length) ? j + concurrency : batch.length;
          final chunk = batch.sublist(j, chunkEnd);
          debugPrint('Processing chunk: startIndex=$j endIndex=$chunkEnd chunkSize=${chunk.length} (zoom $zoom)');

          final futures = chunk.map((tile) async {
            if (_isCancelled) return 0;
            try {
              return await _downloadTileWithRetry(tile['x']!, tile['y']!, zoom, tempId, forceDownload: forceDownload);
            } catch (e) {
              if (kDebugMode) debugPrint('Tile error: $e');
              return 0;
            }
          }).toList();

          final results = await Future.wait(futures);

          final actualDownloads = results.where((size) => size > 0).length;
          if (actualDownloads < chunk.length) {
            final existing = chunk.length - actualDownloads;
            debugPrint('Chunk: $actualDownloads nuevos, $existing ya existían (zoom $zoom)');
          } else {
            debugPrint('Chunk completed: $actualDownloads new tiles (zoom $zoom)');
          }

          // Contar todos los tiles del chunk como procesados para el progreso (incluye ya existentes)
          downloadedTiles += chunk.length;
          final newTiles = results.where((s) => s > 0).length;
          debugPrint('Chunk result: $newTiles downloaded new tiles, chunk processed ${chunk.length} items. downloadedTiles so far=$downloadedTiles totalTiles=$totalTiles');
          // Ahora reportamos processed, total y nuevos descargados en este chunk
          onProgress?.call(downloadedTiles, totalTiles, newTiles);

          // Pausa corta entre chunks
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    }

    // Marcar descarga finalizada
    _activeDownload = false;
  }

  // Método con reintentos para tiles individuales
  Future<int> _downloadTileWithRetry(int x, int y, int z, String areaId, {int maxRetries = 2, bool forceDownload = false}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      debugPrint('downloadTileWithRetry: tile=$z/$x/$y attempt=${attempt+1}/$maxRetries area=$areaId force=$forceDownload');
      try {
        return await _downloadTile(x, y, z, areaId, forceDownload: forceDownload);
      } catch (e) {
        if (attempt == maxRetries) {
          debugPrint('Failed to download tile after $maxRetries retries: $x,$y,$z');
          return 0; // Falló definitivamente
        }
        // Esperar un poco antes del siguiente intento
        await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
    return 0;
  }

  // Obtener tiles para una región específica
  List<Map<String, int>> _getTilesForRegion(double minLat, double maxLat, double minLng, double maxLng, int zoom) {
    final tiles = <Map<String, int>>[];
    final scale = 1 << zoom;
    final x1 = ((minLng + 180.0) / 360.0 * scale).floor();
    final x2 = ((maxLng + 180.0) / 360.0 * scale).floor();

    final lat1Rad = minLat * (pi / 180.0);
    final lat2Rad = maxLat * (pi / 180.0);

    final y1 = ((1.0 - log(tan(lat1Rad) + (1.0 / cos(lat1Rad))) / pi) / 2.0 * scale).floor();
    final y2 = ((1.0 - log(tan(lat2Rad) + (1.0 / cos(lat2Rad))) / pi) / 2.0 * scale).floor();

    final xStart = x1 <= x2 ? x1 : x2;
    final xEnd = x1 <= x2 ? x2 : x1;
    final yStart = y1 <= y2 ? y1 : y2;
    final yEnd = y1 <= y2 ? y2 : y1;

    for (int x = xStart; x <= xEnd; x++) {
      for (int y = yStart; y <= yEnd; y++) {
        tiles.add({'x': x, 'y': y});
      }
    }
    
    return tiles;
  }

  /// Devuelve un mapa con el conteo de tiles por zoom y el total para una región
  Map<String, dynamic> getTileCountsForRegion(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int minZoom = defaultMinZoom,
    int maxZoom = defaultMaxZoom,
  }) {
    int total = 0;
    final Map<int, int> perZoom = {};
    for (int z = minZoom; z <= maxZoom; z++) {
      final tiles = _getTilesForRegion(minLat, maxLat, minLng, maxLng, z);
      perZoom[z] = tiles.length;
      total += tiles.length;
    }
    return {'total': total, 'perZoom': perZoom};
  }

  /// Cuenta cuántos tiles ya existen en la caché para la región y rango de zooms
  /// Devuelve: { 'total': int, 'existing': int, 'perZoom': {z: totalAtZ}, 'perZoomExisting': {z: existsAtZ} }
  Future<Map<String, dynamic>> countExistingTilesForRegion(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int minZoom = defaultMinZoom,
    int maxZoom = defaultMaxZoom,
  }) async {
    int total = 0;
    int existing = 0;
    final Map<int, int> perZoom = {};
    final Map<int, int> perZoomExisting = {};

    for (int z = minZoom; z <= maxZoom; z++) {
      final tiles = _getTilesForRegion(minLat, maxLat, minLng, maxLng, z);
      perZoom[z] = tiles.length;
      total += tiles.length;

      int existsAtZ = 0;
      // Para cada tile preguntamos a la DB si existe (optimizable con query IN)
      for (final tile in tiles) {
        final rows = await _database!.query(
          'cached_tiles',
          where: 'x = ? AND y = ? AND z = ?',
          whereArgs: [tile['x'], tile['y'], z],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final filePath = rows.first['filePath'] as String?;
          if (filePath != null) {
            final f = File(filePath);
            if (await f.exists()) {
              existsAtZ++;
            } else {
              // si metadata existe pero archivo falta, limpiamos la fila para futuras contadas
              await _database!.delete('cached_tiles', where: 'x = ? AND y = ? AND z = ?', whereArgs: [tile['x'], tile['y'], z]);
            }
          }
        }
      }

      perZoomExisting[z] = existsAtZ;
      existing += existsAtZ;
    }

    return {
      'total': total,
      'existing': existing,
      'perZoom': perZoom,
      'perZoomExisting': perZoomExisting,
    };
  }

  // Cancelar descarga actual
  void cancelDownload() {
    _isCancelled = true;
    _activeDownload = false;
    if (kDebugMode) debugPrint('Download cancellation requested');
  }
  
  // Resetear estado de cancelación (llamar antes de iniciar nueva descarga)
  void _resetCancellation() {
    _isCancelled = false;
  }
  
  // Verificar si la descarga fue cancelada (compatibilidad con la UI):
  // mantiene la semántica anterior donde `isDownloading` era true mientras NO se hubiese cancelado.
  bool get isDownloading => _activeDownload && !_isCancelled;

  // Indica si hay una descarga activa en curso (y no fue cancelada)
  bool get isDownloadingActive => _activeDownload && !_isCancelled;

  // Verificar si una región está completamente descargada
  Future<bool> isRegionComplete(
    double minLat,
    double maxLat,
    double minLng,
    double maxLng, {
    int minZoom = defaultMinZoom,
    int maxZoom = defaultMaxZoom,
  }) async {
    int totalExpected = 0;
    int totalExists = 0;

    for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
      final tiles = _getTilesForRegion(minLat, maxLat, minLng, maxLng, zoom);
      totalExpected += tiles.length;
      
      for (final tile in tiles) {
        final existingTiles = await _database!.query(
          'cached_tiles',
          where: 'x = ? AND y = ? AND z = ?',
          whereArgs: [tile['x'], tile['y'], zoom],
        );
        
        if (existingTiles.isNotEmpty) {
          // Verificar que el archivo físico existe
          final filePath = existingTiles.first['filePath'] as String;
          final file = File(filePath);
          if (await file.exists()) {
            totalExists++;
          }
        }
      }
    }

    final completionPercentage = totalExpected > 0 ? (totalExists / totalExpected) * 100 : 0;
  debugPrint('Región: $totalExists/$totalExpected tiles (${completionPercentage.toStringAsFixed(1)}%)');
    
    // Considerar completo si tiene al menos 95% de los tiles
    return completionPercentage >= 95.0;
  }

  // Cerrar servicio
  Future<void> dispose() async {
    _isCancelled = true;
    await _downloadProgressController.close();
    await _database?.close();
    _database = null;
  }
}