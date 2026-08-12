import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

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
    final month = int.parse(parts[0]);
    final day = int.parse(parts[1]);
    return DateTime(year, month, day);
  }

  /// Fetches holiday data for the given year from API and caches it.
  /// Returns the number of days cached.
  static Future<int> fetchAndCacheYear(int year) async {
    final client = HttpClient();
    try {
      // timor.tech API: https://timor.tech/api/holiday/year/$year
      final request = await client.getUrl(
        Uri.parse('https://timor.tech/api/holiday/year/$year'),
      );
      request.headers.set('User-Agent', 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36');
      final response = await request.close();

      if (response.statusCode != 200) {
        debugPrint('Holiday API returned status ${response.statusCode}');
        return 0;
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (json['code'] != 0) {
        debugPrint('Holiday API error: ${json['message']}');
        return 0;
      }

      final holiday = json['holiday'] as Map<String, dynamic>;
      final db = _database();
      if (db == null) return 0;
      int count = 0;
      // Use a batch for efficient insertion
      final batch = db.batch();
      for (final entry in holiday.entries) {
        final dateStr = entry.key; // e.g. "01-01" or "1.1"
        final info = entry.value as Map<String, dynamic>;

        final date = parseDateKey(dateStr, year);
        final isoDate = date.toIso8601String().substring(0, 10);

        final isHoliday = info['holiday'] as bool? ?? false;
        final name = info['name'] as String?;
        // A day in the API can be: holiday=true (rest day) or holiday=false (make-up workday)
        // If it's in the holiday map but holiday=false, it's a make-up workday (补班)
        final isWorkday = !isHoliday;

        batch.insert(
          _tableName,
          {
            'date': isoDate,
            'name': name,
            'isHoliday': isHoliday ? 1 : 0,
            'isWorkday': isWorkday ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }

      await batch.commit(noResult: true);
      debugPrint('Cached $count holiday entries for $year');
      return count;
    } catch (e, stack) {
      debugPrint('Failed to fetch holiday data for $year: $e\n$stack');
      return 0;
    } finally {
      client.close();
    }
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
        await fetchAndCacheYear(year);
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
