import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/models/alarm_info.dart';
import 'package:alarm_clock/models/week_schedule.dart';
import 'package:alarm_clock/utils/date_utils.dart';

void main() {
  group('weekNumber', () {
    test('returns 1 for Jan 1, 2024', () {
      expect(weekNumber(DateTime(2024, 1, 1)), 1);
    });

    test('returns 2 for Jan 8, 2024', () {
      expect(weekNumber(DateTime(2024, 1, 8)), 2);
    });

    test('returns 53 for Dec 30, 2024', () {
      expect(weekNumber(DateTime(2024, 12, 30)), 53);
    });

    test('returns 54 for Jan 6, 2025', () {
      expect(weekNumber(DateTime(2025, 1, 6)), 54);
    });

    test('Jan 7, 2025 is also week 54', () {
      expect(weekNumber(DateTime(2025, 1, 7)), 54);
    });

    test('Jan 13, 2025 starts week 55', () {
      expect(weekNumber(DateTime(2025, 1, 13)), 55);
    });
  });

  group('autoWeekType', () {
    test('odd week number = single (单休)', () {
      final date = DateTime(2024, 1, 1); // week 1 (odd) → single
      expect(autoWeekType(date), WeekType.single);
    });

    test('even week number = double (双休)', () {
      final date = DateTime(2024, 1, 8); // week 2 (even) → double
      expect(autoWeekType(date), WeekType.double);
    });

    test('alternates every week', () {
      var prev = WeekType.single;
      for (int i = 0; i < 8; i++) {
        final d = DateTime(2024, 1, 1).add(Duration(days: i * 7));
        final wt = autoWeekType(d);
        if (i > 0) {
          expect(wt, prev == WeekType.single ? WeekType.double : WeekType.single,
              reason: 'week ${i + 1} should alternate');
        }
        prev = wt;
      }
    });
  });

  group('resolveWeekType', () {
    test('no override → uses auto', () {
      final date = DateTime(2024, 1, 1); // week 1 = single
      expect(resolveWeekType(date, []), WeekType.single);
    });

    test('override takes priority over auto', () {
      final override = WeekSchedule(
        weekIndex: 1,
        year: 2024,
        month: 1,
        weekOfMonth: 1,
        weekType: WeekType.double, // override to double
      );
      final date = DateTime(2024, 1, 3); // weekNumber=1, would be auto single
      expect(resolveWeekType(date, [override]), WeekType.double);
    });

    test('override for different weekOfMonth does not apply', () {
      final override = WeekSchedule(
        weekIndex: 2,
        year: 2024,
        month: 1,
        weekOfMonth: 2,
        weekType: WeekType.single,
      );
      final date = DateTime(2024, 1, 3); // weekOfMonth=1
      expect(resolveWeekType(date, [override]), WeekType.single); // auto, not override
    });

    test('override for different month does not apply', () {
      final override = WeekSchedule(
        weekIndex: 5,
        year: 2024,
        month: 2,
        weekOfMonth: 1,
        weekType: WeekType.single,
      );
      final date = DateTime(2024, 1, 3);
      expect(resolveWeekType(date, [override]), WeekType.single); // auto
    });
  });

  group('shouldRingOnDate', () {
    group('once', () {
      test('returns true when enabled', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.once);
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 1), []), true);
      });

      test('returns false when disabled', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.once, isEnabled: false);
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 1), []), false);
      });
    });

    group('daily', () {
      test('rings every day', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.daily);
        for (int dow = 1; dow <= 7; dow++) {
          expect(shouldRingOnDate(alarm, DateTime(2024, 1, dow), []), true,
              reason: 'dow=$dow should ring');
        }
      });
    });

    group('weekdays', () {
      test('rings Monday-Friday', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.weekdays);
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 1), []), true);  // Mon
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 5), []), true);  // Fri
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 6), []), false); // Sat
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 7), []), false); // Sun
      });
    });

    group('weekends', () {
      test('rings Saturday-Sunday', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.weekends);
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 6), []), true);  // Sat
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 7), []), true);   // Sun
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 1), []), false); // Mon
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 5), []), false); // Fri
      });
    });

    group('singleRest (单休)', () {
      test('Saturday rings on single-rest weeks', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
        // Jan 6, 2024 = Saturday, week 1 (odd) = single-rest
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 6), []), true);
      });

      test('Sunday does not ring', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 7), []), false);
      });

      test('Mon-Fri always ring', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
        for (int dow = 1; dow <= 5; dow++) {
          expect(shouldRingOnDate(alarm, DateTime(2024, 1, dow), []), true,
              reason: 'dow=$dow should ring');
        }
      });

      test('Saturday does not ring on double-rest week', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
        // Jan 13, 2024 = Saturday, week 2 (even) = double-rest
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 13), []), false);
      });
    });

    group('doubleRest (双休)', () {
      test('Saturday does not ring on double-rest week', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.doubleRest);
        // Jan 13, 2024 = Saturday, week 2 (even) = double-rest → no ring
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 13), []), false);
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 7), []), false); // Sun
      });

      test('Saturday does not ring on single-rest week (workday)', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.doubleRest);
        // Jan 6, 2024 = Saturday, week 1 (odd) = single-rest → Saturday is workday, no ring
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 6), []), false);
      });

      test('Monday-Friday ring', () {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.doubleRest);
        for (int dow = 1; dow <= 5; dow++) {
          expect(shouldRingOnDate(alarm, DateTime(2024, 1, dow), []), true,
              reason: 'dow=$dow should ring');
        }
      });
    });

    group('custom', () {
      test('rings only on selected weekdays', () {
        final alarm = AlarmInfo.create(
          hour: 8,
          minute: 0,
          repeatType: RepeatType.custom,
          weekdays: [1, 3, 5], // Mon, Wed, Fri
        );
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 1), []), true);  // Mon
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 2), []), false); // Tue
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 3), []), true);  // Wed
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 4), []), false); // Thu
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 5), []), true);  // Fri
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 6), []), false); // Sat
        expect(shouldRingOnDate(alarm, DateTime(2024, 1, 7), []), false); // Sun
      });
    });
  });

  group('weekOfMonth', () {
    test('days 1-7 are week 1', () {
      for (int d = 1; d <= 7; d++) {
        expect(weekOfMonth(DateTime(2024, 1, d)), 1, reason: 'day $d');
      }
    });

    test('days 8-14 are week 2', () {
      for (int d = 8; d <= 14; d++) {
        expect(weekOfMonth(DateTime(2024, 1, d)), 2, reason: 'day $d');
      }
    });

    test('day 31 is week 5 in January', () {
      expect(weekOfMonth(DateTime(2024, 1, 31)), 5);
    });

    test('edge: month boundary Dec 31, 2024', () {
      expect(weekOfMonth(DateTime(2024, 12, 31)), 5);
    });
  });

  group('dayLabel', () {
    test('returns correct Chinese labels', () {
      expect(dayLabel(1), '星期一');
      expect(dayLabel(2), '星期二');
      expect(dayLabel(3), '星期三');
      expect(dayLabel(4), '星期四');
      expect(dayLabel(5), '星期五');
      expect(dayLabel(6), '星期六');
      expect(dayLabel(7), '星期日');
    });
  });

  group('weekTypeLabel', () {
    test('returns 单休 for single', () => expect(weekTypeLabel(WeekType.single), '单休'));
    test('returns 双休 for double', () => expect(weekTypeLabel(WeekType.double), '双休'));
  });

  group('getWeekDays', () {
    test('returns 7 days for week 1 of January 2024', () {
      final days = getWeekDays(2024, 1, 1);
      expect(days.length, 7);
      expect(days.first, DateTime(2024, 1, 1));
      expect(days.last, DateTime(2024, 1, 7));
    });

    test('returns 7 days for week 2 of January 2024', () {
      final days = getWeekDays(2024, 1, 2);
      expect(days.length, 7);
      expect(days.first, DateTime(2024, 1, 8));
      expect(days.last, DateTime(2024, 1, 14));
    });

    test('week 5 may have days beyond month', () {
      // January has 31 days; week 5 starts day 29
      final days = getWeekDays(2024, 1, 5);
      expect(days.length, 7);
      expect(days.first, DateTime(2024, 1, 29));
      expect(days.last.day, 4); // Jan 4 = overflow into next month
    });
  });

  group('nextAlarmDate', () {
    test('finds next weekday for weekdays alarm', () {
      final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.weekdays);
      // Start from Sunday Jan 7, 2024 → next should be Mon Jan 8
      final result = nextAlarmDate(alarm, [], from: DateTime(2024, 1, 7));
      expect(result, DateTime(2024, 1, 8));
    });

    test('returns null if no ring day found within 365 days', () {
      final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.once, isEnabled: false);
      final result = nextAlarmDate(alarm, [], from: DateTime(2024, 1, 1));
      expect(result, null);
    });

    test('singleRest: Jan 1 (Mon) is a ringing day, returns start date', () {
      final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
      // Start from Mon Jan 1, 2024 (ringing) → returns Jan 1
      final result = nextAlarmDate(alarm, [], from: DateTime(2024, 1, 1));
      expect(result, DateTime(2024, 1, 1));
    });

    test('singleRest: from Mon of double week, returns that Monday', () {
      final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
      // Jan 8 is Monday of week 2 (double) → Mon always rings
      final result = nextAlarmDate(alarm, [], from: DateTime(2024, 1, 8));
      expect(result, DateTime(2024, 1, 8));
    });

    test('doubleRest: skips both Sat and Sun, finds Monday', () {
      final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.doubleRest);
      // Start from Sat Jan 6, 2024 → Sat & Sun skipped, Mon Jan 8 rings
      final result = nextAlarmDate(alarm, [], from: DateTime(2024, 1, 6));
      expect(result, DateTime(2024, 1, 8));
    });

    test('respects override: forced single week makes Saturday ring', () {
      final override = WeekSchedule(
        weekIndex: 2,
        year: 2024,
        month: 1,
        weekOfMonth: 2,
        weekType: WeekType.single, // force week 2 to single
      );
      final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
      // Jan 13 is Sat in week 2; normally double (no ring), but override forces single → rings
      final result = nextAlarmDate(alarm, [override], from: DateTime(2024, 1, 13));
      expect(result, DateTime(2024, 1, 13));
    });

    test('year boundary: Jan 1, 2024 is Monday (ringing) → returns Jan 1', () {
      final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.singleRest);
      // Jan 1 is Monday → ringing immediately
      final result = nextAlarmDate(alarm, [], from: DateTime(2024, 1, 1));
      expect(result, DateTime(2024, 1, 1));
    });
  });

  group('workday (补班) policy', () {
    AlarmInfo alarmOf(RepeatType t, {List<int> weekdays = const []}) => AlarmInfo.create(
        hour: 7, minute: 0, repeatType: t, weekdays: weekdays);
    final saturday = DateTime(2026, 8, 15); // Saturday
    final sunday = DateTime(2026, 8, 16);   // Sunday

    test('补班日强制 weekdays 类型响', () {
      expect(shouldRingOnDate(alarmOf(RepeatType.weekdays), saturday, [],
          isWorkday: true), isTrue);
    });
    test('补班日强制 doubleRest 响', () {
      expect(shouldRingOnDate(alarmOf(RepeatType.doubleRest), saturday, [],
          isWorkday: true), isTrue);
    });
    test('补班日强制 singleRest 周日响', () {
      expect(shouldRingOnDate(alarmOf(RepeatType.singleRest), sunday, [],
          isWorkday: true), isTrue);
    });
    test('补班日强制 daily 响', () {
      expect(shouldRingOnDate(alarmOf(RepeatType.daily), saturday, [],
          isWorkday: true), isTrue);
    });
    test('补班日不强制 custom', () {
      expect(shouldRingOnDate(
          alarmOf(RepeatType.custom, weekdays: [DateTime.monday]), saturday, [],
          isWorkday: true), isFalse);
    });
    test('补班日不强制 once（未选星期照常响，选了则按星期）', () {
      expect(shouldRingOnDate(alarmOf(RepeatType.once), saturday, [],
          isWorkday: true), isTrue); // weekdays 空 → 正常规则 true
      expect(shouldRingOnDate(
          alarmOf(RepeatType.once, weekdays: [DateTime.monday]), saturday, [],
          isWorkday: true), isFalse);
    });
  });

  group('alarmTimeForDate workday Saturday', () {
    test('双休周周六补班用周六专用时间', () {
      final alarm = AlarmInfo.create(
          hour: 7, minute: 0, repeatType: RepeatType.singleRest,
          saturdayHour: 8, saturdayMinute: 30);
      // 2026-08-15 所在周为偶数周（双休），无 override
      final t = alarmTimeForDate(alarm, DateTime(2026, 8, 15), [],
          isWorkday: true);
      expect(t.hour, 8);
      expect(t.minute, 30);
    });
  });

  group('weekNumber negative dates', () {
    test('2023-12-25 (周一) 为第 0 周', () {
      expect(weekNumber(DateTime(2023, 12, 25)), 0);
      expect(autoWeekType(DateTime(2023, 12, 25)), WeekType.double);
    });
    test('2023-12-18 为第 -1 周（单休，奇偶交替延续）', () {
      expect(weekNumber(DateTime(2023, 12, 18)), -1);
      expect(autoWeekType(DateTime(2023, 12, 18)), WeekType.single);
    });
  });
}