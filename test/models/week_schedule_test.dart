import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/models/week_schedule.dart';

void main() {
  group('WeekSchedule', () {
    group('creation', () {
      test('creates with all fields', () {
        final createdAt = DateTime(2026, 5, 20, 10, 30);
        final schedule = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
          createdAt: createdAt,
        );

        expect(schedule.id, 1);
        expect(schedule.year, 2026);
        expect(schedule.month, 5);
        expect(schedule.weekOfMonth, 3);
        expect(schedule.weekType, WeekType.single);
        expect(schedule.createdAt, createdAt);
      });

      test('creates without id (new record)', () {
        final schedule = WeekSchedule(
          year: 2026,
          month: 6,
          weekOfMonth: 1,
          weekType: WeekType.double,
        );

        expect(schedule.id, isNull);
        expect(schedule.year, 2026);
        expect(schedule.month, 6);
        expect(schedule.weekOfMonth, 1);
        expect(schedule.weekType, WeekType.double);
        expect(schedule.createdAt, isNotNull);
      });

      test('defaults createdAt to DateTime.now()', () {
        final before = DateTime.now();
        final schedule = WeekSchedule(
          year: 2026,
          month: 7,
          weekOfMonth: 2,
          weekType: WeekType.single,
        );
        final after = DateTime.now();

        expect(schedule.createdAt.isAfter(before) || schedule.createdAt.isAtSameMomentAs(before), isTrue);
        expect(schedule.createdAt.isBefore(after) || schedule.createdAt.isAtSameMomentAs(after), isTrue);
      });
    });

    group('toMap/fromMap round-trip', () {
      test('round-trip preserves all fields', () {
        final original = WeekSchedule(
          id: 42,
          year: 2026,
          month: 3,
          weekOfMonth: 4,
          weekType: WeekType.double,
          createdAt: DateTime(2026, 3, 15, 8, 0),
        );

        final map = original.toMap();
        final restored = WeekSchedule.fromMap(map);

        expect(restored.id, original.id);
        expect(restored.year, original.year);
        expect(restored.month, original.month);
        expect(restored.weekOfMonth, original.weekOfMonth);
        expect(restored.weekType, original.weekType);
        expect(restored.createdAt, original.createdAt);
      });

      test('round-trip without id', () {
        final original = WeekSchedule(
          year: 2026,
          month: 12,
          weekOfMonth: 5,
          weekType: WeekType.single,
        );

        final map = original.toMap();
        expect(map.containsKey('id'), isFalse);

        final restored = WeekSchedule.fromMap(map);
        expect(restored.id, isNull);
      });

      test('fromMap handles WeekType by index', () {
        final map = {
          'id': 1,
          'year': 2026,
          'month': 1,
          'weekOfMonth': 1,
          'weekType': 1, // WeekType.double
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        };

        final schedule = WeekSchedule.fromMap(map);
        expect(schedule.weekType, WeekType.double);
      });
    });

    group('equality', () {
      test('equal schedules with same values', () {
        final createdAt = DateTime(2026, 5, 20);
        final a = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
          createdAt: createdAt,
        );
        final b = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
          createdAt: createdAt,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal with different id', () {
        final createdAt = DateTime(2026, 5, 20);
        final a = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
          createdAt: createdAt,
        );
        final b = WeekSchedule(
          id: 2,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
          createdAt: createdAt,
        );

        expect(a, isNot(equals(b)));
      });

      test('not equal with different weekType', () {
        final createdAt = DateTime(2026, 5, 20);
        final a = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
          createdAt: createdAt,
        );
        final b = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.double,
          createdAt: createdAt,
        );

        expect(a, isNot(equals(b)));
      });
    });

    group('copyWith', () {
      test('copies with id override', () {
        final original = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
        );

        final copy = original.copyWith(id: 99);

        expect(copy.id, 99);
        expect(copy.year, original.year);
        expect(copy.month, original.month);
        expect(copy.weekOfMonth, original.weekOfMonth);
        expect(copy.weekType, original.weekType);
        expect(copy.createdAt, original.createdAt);
      });

      test('copies with all fields override', () {
        final original = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
        );

        final newCreatedAt = DateTime(2027, 1, 1);
        final copy = original.copyWith(
          id: 2,
          year: 2027,
          month: 1,
          weekOfMonth: 1,
          weekType: WeekType.double,
          createdAt: newCreatedAt,
        );

        expect(copy.id, 2);
        expect(copy.year, 2027);
        expect(copy.month, 1);
        expect(copy.weekOfMonth, 1);
        expect(copy.weekType, WeekType.double);
        expect(copy.createdAt, newCreatedAt);
      });

      test('copyWith returns equivalent object when no args', () {
        final original = WeekSchedule(
          id: 1,
          year: 2026,
          month: 5,
          weekOfMonth: 3,
          weekType: WeekType.single,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });

    group('WeekType enum', () {
      test('has single and double values', () {
        expect(WeekType.values, contains(WeekType.single));
        expect(WeekType.values, contains(WeekType.double));
        expect(WeekType.values.length, 2);
      });

      test('single has index 0', () {
        expect(WeekType.single.index, 0);
      });

      test('double has index 1', () {
        expect(WeekType.double.index, 1);
      });
    });
  });
}