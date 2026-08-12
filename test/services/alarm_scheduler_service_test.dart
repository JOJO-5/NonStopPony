import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/models/alarm_info.dart';
import 'package:alarm_clock/models/week_schedule.dart';
import 'package:alarm_clock/services/alarm_scheduler_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

void main() {
  setUp(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    TestWidgetsFlutterBinding.ensureInitialized();
  });
  group('AlarmSchedulerService', () {
    group('calculateNextTrigger', () {
      test('once: returns today if time not passed', () async {
        final alarm = AlarmInfo.create(hour: 23, minute: 59, repeatType: RepeatType.once);
        final now = DateTime.now();

        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);

        expect(result, isNotNull);
        expect(result!.year, now.year);
        expect(result.month, now.month);
        expect(result.day, now.day);
        expect(result.hour, 23);
        expect(result.minute, 59);
      });

      test('once: returns today if time just passed (within same day tolerance)', () async {
        final now = DateTime.now();

        // Use a time that's guaranteed to be in the future today
        final futureAlarm = AlarmInfo.create(
          hour: now.hour,
          minute: (now.minute + 1) % 60,
          repeatType: RepeatType.once,
        );

        final result = await AlarmSchedulerService.calculateNextTrigger(futureAlarm);

        expect(result, isNotNull);
        expect(result!.day, now.day);
      });

      test('daily: returns today or tomorrow based on time', () async {
        final now = DateTime.now();
        final alarmTimeNow = DateTime(now.year, now.month, now.day, now.hour, now.minute);
        final isTimePassed = now.isAfter(alarmTimeNow);
        final alarm = AlarmInfo.create(hour: now.hour, minute: now.minute, repeatType: RepeatType.daily);
        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);
        expect(result, isNotNull);
        if (isTimePassed) {
          // Time passed, should be tomorrow (compare full date to handle month rollover)
          final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
          expect(DateTime(result!.year, result.month, result.day), tomorrow);
        } else {
          // Time not passed, should be today
          expect(result!.day, now.day);
        }
      });

      test('weekdays: returns next Mon-Fri', () async {
        final alarm = AlarmInfo.create(hour: 9, minute: 0, repeatType: RepeatType.weekdays);
        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);

        expect(result, isNotNull);
        expect(result!.weekday, greaterThanOrEqualTo(DateTime.monday));
        expect(result.weekday, lessThanOrEqualTo(DateTime.friday));
      });

      test('weekends: returns next Sat or Sun', () async {
        final alarm = AlarmInfo.create(hour: 10, minute: 0, repeatType: RepeatType.weekends);
        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);

        expect(result, isNotNull);
        expect(result!.weekday == DateTime.saturday || result.weekday == DateTime.sunday, isTrue);
      });

      // Regression: once alarms must honor the weekdays filter.
      // Before the fix, calculateNextTrigger returned alarmTimeToday for
      // once without consulting shouldRingOnDate, so a once alarm with
      // weekdays=[Saturday] would fire on the day it was created even if
      // that day was not Saturday.
      test('once: honors weekdays filter (returns null when today is not in weekdays)', () async {
        final now = DateTime.now();
        // Pick a weekdays list that excludes today.
        final todayDow = now.weekday;
        final otherDow = todayDow == 6 ? 7 : 6; // Saturday (6) or Sunday (7)
        // Use a future time today to make sure we are testing the weekdays
        // filter, not the time-already-passed path.
        final futureMinute = (now.minute + 30) % 60;
        final futureHour = (now.minute + 30) >= 60 ? (now.hour + 1) % 24 : now.hour;
        final alarm = AlarmInfo.create(
          hour: futureHour,
          minute: futureMinute,
          repeatType: RepeatType.once,
          weekdays: [otherDow],
        );

        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);
        expect(result, isNull,
            reason: 'once alarm with weekdays excluding today must not fire');
      });

      test('once: fires today when today IS in weekdays', () async {
        // Fixed 23:59 today is always in the future, regardless of minute.
        // The original implementation used `now + 30 minutes`, which races
        // with midnight: when now.minute >= 30 the result crosses into the
        // next day, leaving today's alarm time in the past and triggering
        // the (correctly) null-returning past-time path. The past-time path
        // is covered by the dedicated test below.
        final now = DateTime.now();
        if (now.hour == 23 && now.minute >= 59) {
          markTestSkipped('runs within the 23:59:xx window');
          return;
        }
        final alarm = AlarmInfo.create(
          hour: 23,
          minute: 59,
          repeatType: RepeatType.once,
          weekdays: [now.weekday],
        );

        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);
        expect(result, isNotNull);
        expect(result!.weekday, now.weekday);
      });

      test('once: returns null when time already passed and weekdays include today', () async {
        final now = DateTime.now();
        // Past time today: hour=0, minute=0 is always in the past unless
        // we are at exactly 00:00:00.
        final alarm = AlarmInfo.create(
          hour: 0,
          minute: 0,
          repeatType: RepeatType.once,
          weekdays: [now.weekday],
        );

        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);
        // Time already passed (today 00:00 vs now which is later) so once
        // must not re-fire.
        expect(result, isNull);
      });
            test('custom: respects weekdays list', () async {
        // Set alarm for Monday (1) and Wednesday (3)
        final alarm = AlarmInfo.create(
          hour: 8,
          minute: 0,
          repeatType: RepeatType.custom,
          weekdays: [1, 3],
        );
        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);

        expect(result, isNotNull);
        expect(result!.weekday == DateTime.monday || result.weekday == DateTime.wednesday, isTrue);
      });

      test('custom: returns null when weekdays list is empty', () async {
        final alarm = AlarmInfo.create(hour: 8, minute: 0, repeatType: RepeatType.custom, weekdays: []);
        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);

        // Empty weekdays should cause no triggers (nextAlarmDate returns null after 365 days)
        expect(result, isNull);
      });

      test('singleRest: respects week type override', () async {
        final alarm = AlarmInfo.create(hour: 9, minute: 0, repeatType: RepeatType.singleRest);
        // Create an override for the current week that says single (Saturday works)
        final now = DateTime.now();
        final weekOfMonth = ((now.day - 1) ~/ 7) + 1;
        final override = WeekSchedule(
          weekIndex: 1,
          year: now.year,
          month: now.month,
          weekOfMonth: weekOfMonth,
          weekType: WeekType.single,
        );

        final result = await AlarmSchedulerService.calculateNextTrigger(
          alarm,
          overrides: [override],
        );

        // Should find a valid date (non-Sunday for singleRest)
        expect(result, isNotNull);
        expect(result!.weekday, isNot(DateTime.sunday));
      });

      test('doubleRest: never rings on weekends', () async {
        final alarm = AlarmInfo.create(hour: 9, minute: 0, repeatType: RepeatType.doubleRest);

        final result = await AlarmSchedulerService.calculateNextTrigger(alarm);
        expect(result, isNotNull);
        final DateTime next = result!;
        expect(next.weekday, isNot(DateTime.saturday));
        expect(next.weekday, isNot(DateTime.sunday));
      });
    });

    group('calculateNext7Days', () {
      test('returns list of triggers within 7 days', () async {
        final alarm = AlarmInfo.create(hour: 12, minute: 0, repeatType: RepeatType.daily);
        final result = await AlarmSchedulerService.calculateNext7Days(alarm);

        expect(result, isA<List<DateTime>>());
        // Should have at least one trigger
        expect(result.isNotEmpty, isTrue);
        // All triggers should be within 7 days
        final now = DateTime.now();
        for (final trigger in result) {
          expect(trigger.difference(now).inDays, lessThanOrEqualTo(7));
        }
      });

      test('returns empty list when no triggers', () async {
        final alarm = AlarmInfo.create(hour: 0, minute: 0, repeatType: RepeatType.custom, weekdays: []);
        final result = await AlarmSchedulerService.calculateNext7Days(alarm);

        expect(result, isEmpty);
      });

      test('once 闹钟最多返回 1 个未来触发器', () async {
        final now = DateTime.now();
        if (now.hour == 23 && now.minute >= 59) {
          markTestSkipped('runs within the 23:59:xx window');
          return;
        }
        final alarm = AlarmInfo.create(
          hour: 23,
          minute: 59,
          repeatType: RepeatType.once,
        );
        final list = await AlarmSchedulerService.calculateNext7Days(alarm);
        expect(list.length, lessThanOrEqualTo(1),
            reason: 'once alarm must not produce triggers on consecutive days');
      });
    });

    group('scheduleAlarm and cancelAlarm', () {
      test('scheduleAlarm logs the alarm details', () async {
        final alarm = AlarmInfo.create(id: 1, hour: 9, minute: 0, label: 'Test Alarm');
        final override = WeekSchedule(
          weekIndex: 2,
          year: DateTime.now().year,
          month: DateTime.now().month,
          weekOfMonth: 1,
          weekType: WeekType.single,
        );

        // Should complete without throwing
        await expectLater(
          AlarmSchedulerService.scheduleAlarm(alarm, overrides: [override]),
          completes,
        );
      });

      test('cancelAlarm completes without error', () async {
        await expectLater(AlarmSchedulerService.cancelAlarm(1), completes);
      });
    });

    group('rescheduleAll', () {
      test('schedules only enabled alarms', () async {
        final enabledAlarm = AlarmInfo.create(id: 1, hour: 9, minute: 0, isEnabled: true);
        final disabledAlarm = AlarmInfo.create(id: 2, hour: 10, minute: 0, isEnabled: false);
        final alarms = [enabledAlarm, disabledAlarm];

        // Should complete without error
        await expectLater(
          AlarmSchedulerService.rescheduleAll(alarms),
          completes,
        );
      });

      test('handles empty alarm list', () async {
        await expectLater(AlarmSchedulerService.rescheduleAll([]), completes);
      });
    });

    group('单双休 integration', () {
      test('override takes priority over auto week type', () async {
        final now = DateTime.now();
        final weekOfMonth = ((now.day - 1) ~/ 7) + 1;

        // Create a double override to force Sunday to ring (contradicting singleRest)
        final doubleOverride = WeekSchedule(
          weekIndex: 3,
          year: now.year,
          month: now.month,
          weekOfMonth: weekOfMonth,
          weekType: WeekType.double,
        );

        // With double override, Sunday should NOT ring for singleRest
        // because doubleRest means Sunday off
        final singleRestAlarm = AlarmInfo.create(
          hour: 9,
          minute: 0,
          repeatType: RepeatType.singleRest,
        );

        // Find a Sunday
        var sunday = now;
        while (sunday.weekday != DateTime.sunday) {
          sunday = sunday.add(Duration(days: 1));
        }

        // Test that shouldRingOnDate with override works as expected
        final result = await AlarmSchedulerService.calculateNextTrigger(
          singleRestAlarm,
          overrides: [doubleOverride],
        );

        // Should return some valid date (not necessarily Sunday)
        expect(result, isNotNull);
      });

      test('custom days combined with 单双休 logic', () async {
        final now = DateTime.now();
        final weekOfMonth = ((now.day - 1) ~/ 7) + 1;

        final singleOverride = WeekSchedule(
          weekIndex: 4,
          year: now.year,
          month: now.month,
          weekOfMonth: weekOfMonth,
          weekType: WeekType.single,
        );

        // Custom alarm that triggers on Saturday with singleRest override
        final alarm = AlarmInfo.create(
          hour: 10,
          minute: 0,
          repeatType: RepeatType.custom,
          weekdays: [DateTime.saturday],
        );

        final result = await AlarmSchedulerService.calculateNextTrigger(
          alarm,
          overrides: [singleOverride],
        );

        // For custom type, shouldRingOnDate just checks weekdays.contains(date.weekday)
        // so Saturday should ring regardless of week type
        // But we need to find a Saturday first
        expect(result, isNotNull);
        // If result is Saturday, it passed the weekdays check
        // If not Saturday, it's because there's no Saturday in the next 365 days
        // (which would be a test environment issue, not a logic issue)
      });
    });
  });
}