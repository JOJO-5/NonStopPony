import 'package:sqflite/sqflite.dart';

import '../models/week_schedule.dart';

/// Service for persisting WeekSchedule entries via sqflite.
class ScheduleStorageService {
  static const String _tableName = 'week_schedule';

  static Database? _database;

  /// Sets the shared database instance (called from AlarmStorageService.init).
  static void setDatabase(Database db) {
    _database = db;
  }

  /// Initializes the week_schedule table. Must be called after setDatabase().
  static Future<void> init() async {
    await _database!.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        weekIndex INTEGER NOT NULL DEFAULT 0,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        weekOfMonth INTEGER NOT NULL,
        weekType INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        UNIQUE(year, month, weekOfMonth)
      )
    ''');
  }

  static Database _db() {
    if (_database == null) {
      throw StateError('ScheduleStorageService.setDatabase() must be called before any DB operation');
    }
    return _database!;
  }

  /// Inserts a new entry. Returns the inserted row id.
  static Future<int> insert(WeekSchedule entry) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = entry.toMap();
    map['updatedAt'] = now;
    map.remove('id'); // let DB assign
    return _db().insert(_tableName, map);
  }

  /// Retrieves all entries.
  static Future<List<WeekSchedule>> getAll() async {
    final rows = await _db().query(_tableName, orderBy: 'weekIndex ASC, year ASC, month ASC, weekOfMonth ASC');
    return rows.map((row) => WeekSchedule.fromMap(row)).toList();
  }

  /// Retrieves an entry by its natural key (year, month, weekOfMonth).
  static Future<WeekSchedule?> getByKey(int year, int month, int weekOfMonth) async {
    final rows = await _db().query(
      _tableName,
      where: 'year = ? AND month = ? AND weekOfMonth = ?',
      whereArgs: [year, month, weekOfMonth],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WeekSchedule.fromMap(rows.first);
  }

  /// Retrieves an entry by its absolute week index.
  static Future<WeekSchedule?> getByWeekIndex(int weekIndex) async {
    final rows = await _db().query(
      _tableName,
      where: 'weekIndex = ?',
      whereArgs: [weekIndex],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WeekSchedule.fromMap(rows.first);
  }

  /// Retrieves all entries for a given year and month.
  static Future<List<WeekSchedule>> getByMonth(int year, int month) async {
    final rows = await _db().query(
      _tableName,
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      orderBy: 'weekOfMonth ASC',
    );
    return rows.map((row) => WeekSchedule.fromMap(row)).toList();
  }

  /// Updates an existing entry. Returns rows affected.
  /// The entry must have a non-null id.
  static Future<int> update(WeekSchedule entry) async {
    if (entry.id == null) {
      throw ArgumentError('Cannot update an entry with null id');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = entry.toMap();
    map['updatedAt'] = now;
    return _db().update(
      _tableName,
      map,
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Deletes an entry by its row id. Returns rows affected.
  static Future<int> delete(int id) async {
    return _db().delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes an entry by its natural key. Returns rows affected.
  static Future<int> deleteByKey(int year, int month, int weekOfMonth) async {
    return _db().delete(
      _tableName,
      where: 'year = ? AND month = ? AND weekOfMonth = ?',
      whereArgs: [year, month, weekOfMonth],
    );
  }

  /// Deletes an entry by its absolute week index. Returns rows affected.
  static Future<int> deleteByWeekIndex(int weekIndex) async {
    return _db().delete(
      _tableName,
      where: 'weekIndex = ?',
      whereArgs: [weekIndex],
    );
  }

  /// Inserts or replaces an entry by its natural key.
  static Future<int> upsert(WeekSchedule entry) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = entry.toMap();
    map['updatedAt'] = now;
    map.remove('id'); // INSERT OR REPLACE ignores explicit id; let DB generate
    return _db().insert(
      _tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Closes the database. Intended for test cleanup between suites.
  static Future<void> close() async {
    final db = _database;
    _database = null;
    if (db != null) {
      await db.close();
    }
  }

  /// Deletes all entries from the table. Useful for test isolation.
  static Future<int> deleteAll() async {
    return _db().delete(_tableName);
  }
}
