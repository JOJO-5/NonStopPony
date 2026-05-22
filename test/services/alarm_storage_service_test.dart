import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alarm_clock/services/alarm_storage_service.dart';
import 'package:alarm_clock/models/alarm_info.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('alarm_clock_test');
  });

  setUp(() async {
    await AlarmStorageService.init(databasePath: tempDir.path);
  });

  tearDown(() async {
    await AlarmStorageService.close();
    final dbFile = File('${tempDir.path}/alarm_clock.db');
    if (await dbFile.exists()) {
      await dbFile.delete();
    }
  });

  group('AlarmStorageService CRUD', () {
    test('insert and getAll returns inserted alarm', () async {
      final alarm = AlarmInfo(
        hour: 7,
        minute: 30,
        repeatType: RepeatType.daily,
        weekdays: [],
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: true,
      );

      final id = await AlarmStorageService.insert(alarm);
      expect(id, greaterThan(0));

      final alarms = await AlarmStorageService.getAll();
      expect(alarms.length, 1);
      expect(alarms[0].hour, 7);
      expect(alarms[0].minute, 30);
      expect(alarms[0].repeatType, RepeatType.daily);
      expect(alarms[0].isEnabled, true);
    });

    test('getById returns correct alarm', () async {
      final alarm = AlarmInfo(
        hour: 8,
        minute: 0,
        repeatType: RepeatType.weekdays,
        weekdays: [1, 2, 3, 4, 5],
        vibrate: true,
        snoozeMinutes: 10,
        isEnabled: false,
      );

      final id = await AlarmStorageService.insert(alarm);
      final fetched = await AlarmStorageService.getById(id);

      expect(fetched, isNotNull);
      expect(fetched!.hour, 8);
      expect(fetched.minute, 0);
      expect(fetched.repeatType, RepeatType.weekdays);
      expect(fetched.weekdays, [1, 2, 3, 4, 5]);
      expect(fetched.snoozeMinutes, 10);
      expect(fetched.isEnabled, false);
    });

    test('getById returns null for non-existent id', () async {
      final fetched = await AlarmStorageService.getById(999);
      expect(fetched, isNull);
    });

    test('update modifies existing alarm', () async {
      final alarm = AlarmInfo(
        hour: 9,
        minute: 0,
        repeatType: RepeatType.once,
        weekdays: [],
        label: 'Original',
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: true,
      );

      final id = await AlarmStorageService.insert(alarm);
      final inserted = await AlarmStorageService.getById(id);

      final updated = AlarmInfo(
        id: inserted!.id,
        hour: 10,
        minute: 30,
        repeatType: RepeatType.daily,
        weekdays: inserted.weekdays,
        label: 'Updated',
        vibrate: false,
        snoozeMinutes: 10,
        isEnabled: false,
      );

      await AlarmStorageService.update(updated);
      final fetched = await AlarmStorageService.getById(id);

      expect(fetched!.hour, 10);
      expect(fetched.minute, 30);
      expect(fetched.label, 'Updated');
      expect(fetched.vibrate, false);
      expect(fetched.snoozeMinutes, 10);
      expect(fetched.isEnabled, false);
    });

    test('delete removes alarm', () async {
      final alarm = AlarmInfo(
        hour: 7,
        minute: 30,
        repeatType: RepeatType.once,
        weekdays: [],
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: true,
      );

      final id = await AlarmStorageService.insert(alarm);
      await AlarmStorageService.delete(id);

      final fetched = await AlarmStorageService.getById(id);
      expect(fetched, isNull);
    });

    test('toggleEnabled changes alarm enabled state', () async {
      final alarm = AlarmInfo(
        hour: 7,
        minute: 30,
        repeatType: RepeatType.once,
        weekdays: [],
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: true,
      );

      final id = await AlarmStorageService.insert(alarm);

      await AlarmStorageService.toggleEnabled(id, false);
      var fetched = await AlarmStorageService.getById(id);
      expect(fetched!.isEnabled, false);

      await AlarmStorageService.toggleEnabled(id, true);
      fetched = await AlarmStorageService.getById(id);
      expect(fetched!.isEnabled, true);
    });

    test('getAll orders alarms by time', () async {
      final alarm1 = AlarmInfo(
        hour: 12,
        minute: 0,
        repeatType: RepeatType.once,
        weekdays: [],
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: true,
      );
      final alarm2 = AlarmInfo(
        hour: 6,
        minute: 30,
        repeatType: RepeatType.once,
        weekdays: [],
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: true,
      );
      final alarm3 = AlarmInfo(
        hour: 9,
        minute: 15,
        repeatType: RepeatType.once,
        weekdays: [],
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: true,
      );

      await AlarmStorageService.insert(alarm1);
      await AlarmStorageService.insert(alarm2);
      await AlarmStorageService.insert(alarm3);

      final alarms = await AlarmStorageService.getAll();
      expect(alarms.length, 3);
      expect(alarms[0].hour * 60 + alarms[0].minute, 6 * 60 + 30);
      expect(alarms[1].hour * 60 + alarms[1].minute, 9 * 60 + 15);
      expect(alarms[2].hour * 60 + alarms[2].minute, 12 * 60 + 0);
    });
  });
}