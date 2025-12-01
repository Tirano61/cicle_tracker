import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cycling_session.dart';
import '../models/imported_route.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'cycling_app.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE imported_routes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              description TEXT,
              gpx_text TEXT,
              route_points TEXT NOT NULL,
              distance_km REAL NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
            )
          ''');
        }
      },
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cycling_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startTime INTEGER NOT NULL,
        endTime INTEGER,
        distanceKm REAL NOT NULL DEFAULT 0,
        averageSpeedKmh REAL NOT NULL DEFAULT 0,
        maxSpeedKmh REAL NOT NULL DEFAULT 0,
        caloriesBurned REAL NOT NULL DEFAULT 0,
        duration INTEGER NOT NULL DEFAULT 0,
        routePoints TEXT NOT NULL DEFAULT '',
        speeds TEXT NOT NULL DEFAULT '',
        isCompleted INTEGER NOT NULL DEFAULT 0,
        createdAt INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
      )
    ''');

    // Crear índices para mejorar el rendimiento
    await db.execute('''
      CREATE INDEX idx_cycling_sessions_start_time ON cycling_sessions(startTime)
    ''');

    await db.execute('''
      CREATE INDEX idx_cycling_sessions_completed ON cycling_sessions(isCompleted)
    ''');
    // Asegurar que la tabla imported_routes exista en creación nueva
    await db.execute('''
      CREATE TABLE IF NOT EXISTS imported_routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        description TEXT,
        gpx_text TEXT,
        route_points TEXT NOT NULL,
        distance_km REAL NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
      )
    ''');
  }

  // Insertar nueva sesión de ciclismo
  Future<int> insertCyclingSession(CyclingSession session) async {
    final db = await database;
    return await db.insert('cycling_sessions', session.toMap());
  }

  // Actualizar sesión existente
  Future<int> updateCyclingSession(CyclingSession session) async {
    final db = await database;
    return await db.update(
      'cycling_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  // Obtener todas las sesiones completadas
  Future<List<CyclingSession>> getAllCompletedSessions() async {
    final db = await database;
    final maps = await db.query(
      'cycling_sessions',
      where: 'isCompleted = ?',
      whereArgs: [1],
      orderBy: 'startTime DESC',
    );

    return List.generate(maps.length, (i) {
      return CyclingSession.fromMap(maps[i]);
    });
  }

  // Obtener sesiones por rango de fechas
  Future<List<CyclingSession>> getSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'cycling_sessions',
      where: 'startTime >= ? AND startTime <= ? AND isCompleted = ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
        1,
      ],
      orderBy: 'startTime DESC',
    );

    return List.generate(maps.length, (i) {
      return CyclingSession.fromMap(maps[i]);
    });
  }

  // Obtener sesión por ID
  Future<CyclingSession?> getSessionById(int id) async {
    final db = await database;
    final maps = await db.query(
      'cycling_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CyclingSession.fromMap(maps.first);
    }
    return null;
  }

  // Obtener última sesión incompleta (para continuar tracking)
  Future<CyclingSession?> getLastIncompleteSession() async {
    final db = await database;
    final maps = await db.query(
      'cycling_sessions',
      where: 'isCompleted = ?',
      whereArgs: [0],
      orderBy: 'startTime DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return CyclingSession.fromMap(maps.first);
    }
    return null;
  }

  // Eliminar sesión
  Future<int> deleteSession(int id) async {
    final db = await database;
    return await db.delete(
      'cycling_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Obtener estadísticas generales
  Future<Map<String, double>> getOverallStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as totalSessions,
        COALESCE(SUM(distanceKm), 0) as totalDistance,
        COALESCE(AVG(averageSpeedKmh), 0) as avgSpeed,
        COALESCE(SUM(caloriesBurned), 0) as totalCalories,
        COALESCE(SUM(duration), 0) as totalDuration
      FROM cycling_sessions 
      WHERE isCompleted = 1
    ''');

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'totalSessions': (row['totalSessions'] as int).toDouble(),
        'totalDistance': (row['totalDistance'] as num).toDouble(),
        'avgSpeed': (row['avgSpeed'] as num).toDouble(),
        'totalCalories': (row['totalCalories'] as num).toDouble(),
        'totalDuration': (row['totalDuration'] as int).toDouble(),
      };
    }

    return {
      'totalSessions': 0.0,
      'totalDistance': 0.0,
      'avgSpeed': 0.0,
      'totalCalories': 0.0,
      'totalDuration': 0.0,
    };
  }

  // Eliminar todas las sesiones (para testing o reset)
  Future<int> deleteAllSessions() async {
    final db = await database;
    return await db.delete('cycling_sessions');
  }

  // Cerrar base de datos
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // CRUD para rutas importadas
  Future<int> insertImportedRoute(ImportedRoute route) async {
    final db = await database;
    return await db.insert('imported_routes', route.toMap());
  }

  Future<List<ImportedRoute>> getAllImportedRoutes() async {
    final db = await database;
    final maps = await db.query('imported_routes', orderBy: 'created_at DESC');
    return maps.map((m) => ImportedRoute.fromMap(m)).toList();
  }

  Future<int> deleteImportedRoute(int id) async {
    final db = await database;
    return await db.delete('imported_routes', where: 'id = ?', whereArgs: [id]);
  }
}