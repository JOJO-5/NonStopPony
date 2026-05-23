import 'package:sqflite/sqflite.dart';
import '../models/alarm_info.dart';
import 'holiday_service.dart';
import 'schedule_storage_service.dart';

class AlarmStorageService {
  static const String _dbName = 'alarm_clock.db';
  static const int _dbVersion = 4;
  static const String _tableName = 'alarms';

  static late Database _db;

  /// Expose the database instance for other services that share the same DB.
  static Database get database => _db;

  static Future<void> init({String? databasePath}) async {
    final path = databasePath ?? await getDatabasesPath();
    _db = await openDatabase(
      '$path/$_dbName',
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hour INTEGER NOT NULL,
            minute INTEGER NOT NULL,
            repeatType INTEGER NOT NULL,
            weekdays TEXT,
            label TEXT,
            vibrate INTEGER NOT NULL,
            snoozeMinutes INTEGER NOT NULL,
            isEnabled INTEGER NOT NULL,
            ringtone TEXT NOT NULL DEFAULT 'default',
            ringtoneTitle TEXT NOT NULL DEFAULT '默认',
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        // Create holiday cache table for new installs
        await HolidayService.createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $_tableName ADD COLUMN ringtone TEXT NOT NULL DEFAULT 'default'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE $_tableName ADD COLUMN ringtoneTitle TEXT NOT NULL DEFAULT '默认'",
          );
          // Migrate old ringtone names to URI format
          await db.execute(
            "UPDATE $_tableName SET ringtone = 'default' WHERE ringtone = '默认'",
          );
        }
        if (oldVersion < 4) {
          // Create holiday cache table
          await HolidayService.createTable(db);
        }
      },
    );

    // Share the database with HolidayService
    HolidayService.setDatabase(_db);
    // Share the database with ScheduleStorageService (same DB, avoids opening a second connection)
    ScheduleStorageService.setDatabase(_db);
    await ScheduleStorageService.init();
  }

  static Future<int> insert(AlarmInfo alarm) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = alarm.toMap();
    map['createdAt'] = now;
    map['updatedAt'] = now;
    return await _db.insert(_tableName, map);
  }

  static Future<List<AlarmInfo>> getAll() async {
    final maps = await _db.query(_tableName);
    final alarms = maps.map((map) => AlarmInfo.fromMap(map)).toList();
    alarms.sort((a, b) {
      final aMinutes = a.hour * 60 + a.minute;
      final bMinutes = b.hour * 60 + b.minute;
      return aMinutes.compareTo(bMinutes);
    });
    return alarms;
  }

  static Future<AlarmInfo?> getById(int id) async {
    final maps = await _db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return AlarmInfo.fromMap(maps.first);
  }

  static Future<int> update(AlarmInfo alarm) async {
    final map = alarm.toMap();
    map['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    return await _db.update(
      _tableName,
      map,
      where: 'id = ?',
      whereArgs: [alarm.id],
    );
  }

  static Future<int> delete(int id) async {
    return await _db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> toggleEnabled(int id, bool enabled) async {
    return await _db.update(
      _tableName,
      {
        'isEnabled': enabled ? 1 : 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> close() async {
    await _db.close();
  }
}