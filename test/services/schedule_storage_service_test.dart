import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:alarm_clock/models/week_schedule.dart';
import 'package:alarm_clock/services/schedule_storage_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await ScheduleStorageService.init();
    await ScheduleStorageService.deleteAll();
  });

  tearDown(() async {
    await ScheduleStorageService.close();
  });

  group('ScheduleStorageService', () {
    test('insert + getByKey returns the inserted entry', () async {
      final entry = WeekSchedule(
        year: 2025,
        month: 6,
        weekOfMonth: 1,
        weekType: WeekType.single,
      );
      final id = await ScheduleStorageService.insert(entry);
      expect(id, greaterThan(0));

      final retrieved = await ScheduleStorageService.getByKey(2025, 6, 1);
      expect(retrieved, isNotNull);
      expect(retrieved!.year, 2025);
      expect(retrieved.month, 6);
      expect(retrieved.weekOfMonth, 1);
      expect(retrieved.weekType, WeekType.single);
      expect(retrieved.id, id);
    });

    test('insert + getByMonth returns matching entries', () async {
      final entry1 = WeekSchedule(year: 2025, month: 7, weekOfMonth: 1, weekType: WeekType.single);
      final entry2 = WeekSchedule(year: 2025, month: 7, weekOfMonth: 3, weekType: WeekType.double);
      await ScheduleStorageService.insert(entry1);
      await ScheduleStorageService.insert(entry2);

      final entries = await ScheduleStorageService.getByMonth(2025, 7);
      expect(entries.length, 2);
      expect(entries.map((e) => e.weekOfMonth).toList(), [1, 3]);
    });

    test('getByMonth returns empty list when nothing matches', () async {
      final entries = await ScheduleStorageService.getByMonth(2025, 12);
      expect(entries, isEmpty);
    });

    test('update modifies existing entry', () async {
      final entry = WeekSchedule(year: 2025, month: 8, weekOfMonth: 2, weekType: WeekType.double);
      final id = await ScheduleStorageService.insert(entry);

      final updated = entry.copyWith(id: id, weekType: WeekType.single);
      final rowsAffected = await ScheduleStorageService.update(updated);
      expect(rowsAffected, 1);

      final retrieved = await ScheduleStorageService.getByKey(2025, 8, 2);
      expect(retrieved!.weekType, WeekType.single);
    });

    test('delete removes entry by id', () async {
      final entry = WeekSchedule(year: 2025, month: 9, weekOfMonth: 1, weekType: WeekType.single);
      final id = await ScheduleStorageService.insert(entry);

      final rowsAffected = await ScheduleStorageService.delete(id);
      expect(rowsAffected, 1);

      final retrieved = await ScheduleStorageService.getByKey(2025, 9, 1);
      expect(retrieved, isNull);
    });

    test('deleteByKey removes entry by natural key', () async {
      final entry = WeekSchedule(year: 2025, month: 10, weekOfMonth: 4, weekType: WeekType.double);
      await ScheduleStorageService.insert(entry);

      final rowsAffected = await ScheduleStorageService.deleteByKey(2025, 10, 4);
      expect(rowsAffected, 1);

      final retrieved = await ScheduleStorageService.getByKey(2025, 10, 4);
      expect(retrieved, isNull);
    });

    test('upsert replaces existing entry for same natural key', () async {
      final entry1 = WeekSchedule(year: 2025, month: 11, weekOfMonth: 1, weekType: WeekType.single);
      await ScheduleStorageService.insert(entry1);

      // Upsert with same key but different weekType
      final entry2 = WeekSchedule(year: 2025, month: 11, weekOfMonth: 1, weekType: WeekType.double);
      await ScheduleStorageService.upsert(entry2);

      final retrieved = await ScheduleStorageService.getByKey(2025, 11, 1);
      expect(retrieved!.weekType, WeekType.double);
    });

    test('upsert inserts when key does not exist', () async {
      final entry = WeekSchedule(year: 2025, month: 12, weekOfMonth: 1, weekType: WeekType.double);
      await ScheduleStorageService.upsert(entry);

      final retrieved = await ScheduleStorageService.getByKey(2025, 12, 1);
      expect(retrieved, isNotNull);
      expect(retrieved!.weekType, WeekType.double);
    });

    test('getAll returns all entries ordered by year, month, weekOfMonth', () async {
      await ScheduleStorageService.insert(WeekSchedule(year: 2025, month: 3, weekOfMonth: 2, weekType: WeekType.single));
      await ScheduleStorageService.insert(WeekSchedule(year: 2025, month: 1, weekOfMonth: 1, weekType: WeekType.double));
      await ScheduleStorageService.insert(WeekSchedule(year: 2026, month: 1, weekOfMonth: 1, weekType: WeekType.single));

      final all = await ScheduleStorageService.getAll();
      expect(all.length, 3);
      expect(all[0].year, 2025);
      expect(all[0].month, 1);
      expect(all[1].year, 2025);
      expect(all[1].month, 3);
      expect(all[2].year, 2026);
    });
  });
}