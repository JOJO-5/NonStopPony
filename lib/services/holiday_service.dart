import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

enum HolidayDataSource { network, cache, bundled, unavailable }

class HolidaySyncResult {
  final int year;
  final int count;
  final HolidayDataSource source;
  final String? error;
  const HolidaySyncResult({
    required this.year,
    required this.count,
    required this.source,
    this.error,
  });
  bool get isAvailable => source != HolidayDataSource.unavailable;
}

/// Represents a day's holiday status from the API.
///
/// [name] is the holiday name (e.g. "国庆节"), null if it's a workday.
/// [isHoliday] true if this is a holiday/rest day.
/// [isWorkday] true if this is a make-up workday (补班).
class HolidayInfo {
  final DateTime date;
  final String? name;
  final bool isHoliday;
  final bool isWorkday;

  const HolidayInfo({
    required this.date,
    this.name,
    required this.isHoliday,
    required this.isWorkday,
  });

  factory HolidayInfo.fromMap(Map<String, dynamic> map) {
    return HolidayInfo(
      date: DateTime.parse(map['date'] as String),
      name: map['name'] as String?,
      isHoliday: (map['isHoliday'] as int) == 1,
      isWorkday: (map['isWorkday'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String().substring(0, 10),
      'name': name,
      'isHoliday': isHoliday ? 1 : 0,
      'isWorkday': isWorkday ? 1 : 0,
    };
  }
}

/// Service for fetching and caching Chinese statutory holiday data.
///
/// Uses the free timor.tech API to fetch holiday info for a given year,
/// then caches it locally in SQLite for offline use.
class HolidayService {
  HolidayService._();

  static const String _tableName = 'holiday_cache';
  static Database? _db;
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  static void setDatabase(Database db) {
    _db = db;
  }

  static Database? _database() => _db;

  /// Creates the holiday_cache table. Call during DB migration.
  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        date TEXT PRIMARY KEY,
        name TEXT,
        isHoliday INTEGER NOT NULL DEFAULT 0,
        isWorkday INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Parses a timor.tech holiday date key into a DateTime.
  /// Accepts both "01-01" (dash, zero-padded) and "1.1" (dot, unpadded)
  /// formats — the API has returned both over time.
  static DateTime parseDateKey(String key, int year) {
    final parts = key.split(RegExp(r'[-.]'));
    if (parts.length != 2) {
      throw FormatException('Unexpected holiday date key: $key');
    }
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    if (month == null ||
        day == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateTime(year, month + 1, 0).day) {
      throw FormatException('Unexpected holiday date key: $key');
    }
    return DateTime(year, month, day);
  }

  static Future<HolidaySyncResult> syncYear(
    int year, {
    Future<String> Function(Uri uri)? fetchBody,
  }) async {
    String? failure;
    try {
      final uri = Uri.parse('https://timor.tech/api/holiday/year/$year/');
      final body =
          await (fetchBody == null ? _fetchNetwork(uri) : fetchBody(uri))
              .timeout(const Duration(seconds: 12));
      final count = await _commit(_parseResponse(body, year));
      if (count != null) {
        return HolidaySyncResult(
          year: year,
          count: count,
          source: HolidayDataSource.network,
        );
      }
      failure = '本地数据库不可用';
    } catch (e) {
      failure = '网络同步失败：$e';
    }
    int cached;
    try {
      cached = await _yearCount(year);
    } catch (e) {
      return HolidaySyncResult(
        year: year,
        count: 0,
        source: HolidayDataSource.unavailable,
        error: '本地数据库读取失败：$e',
      );
    }
    if (cached > 0) {
      return HolidaySyncResult(
        year: year,
        count: cached,
        source: HolidayDataSource.cache,
        error: failure,
      );
    }
    if (year == 2026) {
      try {
        final entries = _parseResponse(
          await rootBundle.loadString('assets/holidays/2026.json'),
          year,
        );
        final count = await _commit(entries);
        if (count != null) {
          return HolidaySyncResult(
            year: year,
            count: count,
            source: HolidayDataSource.bundled,
            error: failure,
          );
        }
      } catch (e) {
        failure = '$failure；内置数据不可用：$e';
      }
    }
    return HolidaySyncResult(
      year: year,
      count: 0,
      source: HolidayDataSource.unavailable,
      error: failure,
    );
  }

  static Future<String> _fetchNetwork(Uri uri) async {
    final client = HttpClient();
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}', uri: uri);
        }
        return await response.transform(utf8.decoder).join();
      })().timeout(const Duration(seconds: 12));
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> _parseResponse(String body, int year) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic> ||
        json['code'] != 0 ||
        json['holiday'] is! Map ||
        (json['holiday'] as Map).isEmpty) {
      throw const FormatException('节假日响应无效或为空');
    }
    final result = <Map<String, dynamic>>[];
    for (final entry in (json['holiday'] as Map).entries) {
      final info = entry.value;
      if (entry.key is! String || info is! Map || info['holiday'] is! bool) {
        throw const FormatException('节假日条目无效');
      }
      final date = parseDateKey(entry.key as String, year);
      if (date.year != year) throw const FormatException('节假日年份无效');
      final holiday = info['holiday'] as bool;
      result.add({
        'date': date.toIso8601String().substring(0, 10),
        'name': info['name'] as String?,
        'isHoliday': holiday ? 1 : 0,
        'isWorkday': holiday ? 0 : 1,
      });
    }
    return result;
  }

  static Future<int?> _commit(List<Map<String, dynamic>> entries) async {
    final db = _database();
    if (db == null) return null;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in entries) {
        batch.insert(
          _tableName,
          entry,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
    changes.value++;
    return entries.length;
  }

  static Future<int> _yearCount(int year) async {
    final db = _database();
    if (db == null) return 0;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE date >= ? AND date <= ?',
      ['$year-01-01', '$year-12-31'],
    );
    return (rows.first['cnt'] as int?) ?? 0;
  }

  static Future<int> fetchAndCacheYear(int year) async {
    final result = await syncYear(year);
    if (!result.isAvailable) throw StateError(result.error ?? '暂无可用节假日数据');
    return result.count;
  }


  /// Gets holiday info for a specific date.
  /// Returns null if no cached data exists for this date.
  static Future<HolidayInfo?> getHolidayInfo(DateTime date) async {
    final db = _database();
    if (db == null) return null;
    final isoDate = date.toIso8601String().substring(0, 10);
    final rows = await db.query(
      _tableName,
      where: 'date = ?',
      whereArgs: [isoDate],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HolidayInfo.fromMap(rows.first);
  }
  /// Checks if a date is a statutory holiday (rest day).
  static Future<bool> isHoliday(DateTime date) async {
    final info = await getHolidayInfo(date);
    return info?.isHoliday ?? false;
  }
  /// Checks if a date is a make-up workday (补班日).
  static Future<bool> isWorkday(DateTime date) async {
    final info = await getHolidayInfo(date);
    return info?.isWorkday ?? false;
  }

  /// Checks if holiday data is cached for the given year.
  static Future<bool> isYearCached(int year) async {
    final startIso = DateTime(year, 1, 1).toIso8601String().substring(0, 10);
    final endIso = DateTime(year, 12, 31).toIso8601String().substring(0, 10);
    final db = _database();
    if (db == null) return false;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $_tableName WHERE date >= ? AND date <= ?',
      [startIso, endIso],
    );
    return (rows.first['cnt'] as int) > 0;
  }

  /// Ensures holiday data is available for the current and next year.
  /// Fetches from API if not cached. Call on app startup.
  static Future<void> ensureCurrentData() async {
    final now = DateTime.now();
    final yearsToFetch = [now.year, now.year + 1];
    for (final year in yearsToFetch) {
      if (!await isYearCached(year)) {
        debugPrint('Fetching holiday data for $year...');
        await syncYear(year);
      }
    }
  }

  /// Gets all holiday entries for a given month.
  static Future<List<HolidayInfo>> getMonthHolidays(int year, int month) async {
    final startIso = DateTime(year, month, 1).toIso8601String().substring(0, 10);
    final lastDay = (month == 12)
        ? DateTime(year + 1, 1, 1).subtract(const Duration(days: 1))
        : DateTime(year, month + 1, 1).subtract(const Duration(days: 1));
    final endIso = lastDay.toIso8601String().substring(0, 10);
    final db = _database();
    if (db == null) return [];
    final rows = await db.query(
      _tableName,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startIso, endIso],
      orderBy: 'date ASC',
    );
    return rows.map((r) => HolidayInfo.fromMap(r)).toList();
  }

  /// Gets all holiday entries for a given year.
  static Future<List<HolidayInfo>> getYearHolidays(int year) async {
    final startIso = DateTime(year, 1, 1).toIso8601String().substring(0, 10);
    final endIso = DateTime(year, 12, 31).toIso8601String().substring(0, 10);

    final db = _database();
    if (db == null) return [];
    final rows = await db.query(
      _tableName,
      where: 'date >= ? AND date <= ?',
      whereArgs: [startIso, endIso],
      orderBy: 'date ASC',
    );
    return rows.map((r) => HolidayInfo.fromMap(r)).toList();
  }
}
