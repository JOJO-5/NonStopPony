import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/models/alarm_info.dart';

void main() {
  group('AlarmInfo creation', () {
    test('creates with required fields only', () {
      final alarm = AlarmInfo.create(hour: 8, minute: 30);

      expect(alarm.hour, 8);
      expect(alarm.minute, 30);
      expect(alarm.repeatType, RepeatType.once);
      expect(alarm.weekdays, isEmpty);
      expect(alarm.label, isNull);
      expect(alarm.vibrate, true);
      expect(alarm.snoozeMinutes, 5);
      expect(alarm.isEnabled, true);
    });

    test('creates with all fields specified', () {
      final alarm = AlarmInfo.create(
        id: 1,
        hour: 9,
        minute: 0,
        repeatType: RepeatType.weekdays,
        weekdays: [1, 2, 3, 4, 5],
        label: 'Work alarm',
        vibrate: false,
        snoozeMinutes: 10,
        isEnabled: false,
      );

      expect(alarm.id, 1);
      expect(alarm.hour, 9);
      expect(alarm.minute, 0);
      expect(alarm.repeatType, RepeatType.weekdays);
      expect(alarm.weekdays, [1, 2, 3, 4, 5]);
      expect(alarm.label, 'Work alarm');
      expect(alarm.vibrate, false);
      expect(alarm.snoozeMinutes, 10);
      expect(alarm.isEnabled, false);
    });
  });

  group('AlarmInfo toMap/fromMap round-trip', () {
    test('round-trip with all fields', () {
      final original = AlarmInfo.create(
        id: 42,
        hour: 7,
        minute: 15,
        repeatType: RepeatType.doubleRest,
        weekdays: [6, 7],
        label: 'Weekend alarm',
        vibrate: false,
        snoozeMinutes: 8,
        isEnabled: true,
      );

      final map = original.toMap();
      final restored = AlarmInfo.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.hour, original.hour);
      expect(restored.minute, original.minute);
      expect(restored.repeatType, original.repeatType);
      expect(restored.weekdays, original.weekdays);
      expect(restored.label, original.label);
      expect(restored.vibrate, original.vibrate);
      expect(restored.snoozeMinutes, original.snoozeMinutes);
      expect(restored.isEnabled, original.isEnabled);
    });

    test('round-trip with empty weekdays', () {
      final original = AlarmInfo.create(hour: 12, minute: 0);
      final map = original.toMap();
      final restored = AlarmInfo.fromMap(map);

      expect(restored.weekdays, isEmpty);
    });

    test('round-trip without id', () {
      final original = AlarmInfo.create(hour: 6, minute: 30);
      final map = original.toMap();
      expect(map.containsKey('id'), false);

      final restored = AlarmInfo.fromMap(map);
      expect(restored.id, isNull);
    });
  });

  group('RepeatType serialization', () {
    test('serializes all RepeatType values correctly', () {
      for (final repeatType in RepeatType.values) {
        final alarm = AlarmInfo.create(
          hour: 0,
          minute: 0,
          repeatType: repeatType,
        );

        final map = alarm.toMap();
        final restored = AlarmInfo.fromMap(map);

        expect(restored.repeatType, repeatType);
      }
    });
  });

  group('AlarmInfo copyWith', () {
    test('copies with updated hour', () {
      final original = AlarmInfo.create(hour: 8, minute: 30);
      final copied = original.copyWith(hour: 9);

      expect(copied.hour, 9);
      expect(copied.minute, 30);
      expect(copied.repeatType, RepeatType.once);
    });

    test('copies with updated label', () {
      final original = AlarmInfo.create(hour: 8, minute: 30);
      final copied = original.copyWith(label: 'New label');

      expect(copied.label, 'New label');
      expect(original.label, isNull);
    });

    test('copies with updated weekdays', () {
      final original = AlarmInfo.create(hour: 8, minute: 30);
      final copied = original.copyWith(weekdays: [1, 2, 3]);

      expect(copied.weekdays, [1, 2, 3]);
      expect(original.weekdays, isEmpty);
    });

    test('original remains unchanged', () {
      final original = AlarmInfo.create(hour: 8, minute: 30);
      original.copyWith(hour: 10);

      expect(original.hour, 8);
    });

    test('copyWith 可以清空 label', () {
      final alarm = AlarmInfo.create(id: 1, hour: 7, minute: 0, label: '起床');
      expect(alarm.copyWith(clearLabel: true).label, isNull);
    });
  });

  group('fromMap robustness', () {
    test('fromMap 损坏 weekdays 字符串不崩溃', () {
      final alarm = AlarmInfo.fromMap({
        'id': 1, 'hour': 7, 'minute': 0, 'repeatType': 0,
        'weekdays': '1,x,3', 'vibrate': 1, 'snoozeMinutes': 5,
        'isEnabled': 1, 'taskType': 0,
      });
      expect(alarm.weekdays, [1, 3]);
    });
  });
}