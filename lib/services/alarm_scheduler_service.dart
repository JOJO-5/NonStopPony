import '../models/alarm_info.dart';
import '../models/week_schedule.dart';
import '../utils/date_utils.dart';
import 'alarm_notification_service.dart';

/// Service for calculating next alarm trigger times and managing alarm scheduling.
///
/// Integrates with [shouldRingOnDate] and [nextAlarmDate] from date_utils
/// to handle the 单双休 (alternating single/double weekend) scheduling logic.
class AlarmSchedulerService {
  AlarmSchedulerService._();

  /// Calculates the next trigger [DateTime] for the given [alarm].
  ///
  /// Returns `null` if no valid trigger date is found within 365 days.
  ///
  /// For [RepeatType.once] alarms: if the alarm time has already passed
  /// today, returns `null`. Otherwise returns today at the alarm time.
  ///
  /// For [RepeatType.daily]: returns the next occurrence (today if time not
  /// passed, tomorrow otherwise).
  ///
  /// For [RepeatType.weekdays]: finds the next Mon-Fri where [shouldRingOnDate]
  /// passes.
  ///
  /// For [RepeatType.weekends]: finds the next Sat or Sun where
  /// [shouldRingOnDate] passes.
  ///
  /// For [RepeatType.custom]: checks each day in [AlarmInfo.weekdays] for
  /// the next match where [shouldRingOnDate] passes.
  static Future<DateTime?> calculateNextTrigger(
    AlarmInfo alarm, {
    List<WeekSchedule>? overrides,
  }) async {
    final effectiveOverrides = overrides ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alarmTimeToday = DateTime(today.year, today.month, today.day, alarm.hour, alarm.minute);

    switch (alarm.repeatType) {
      case RepeatType.once:
        // For a one-time alarm we look at today first; if that time has already
        // passed we try tomorrow. This handles the common case of setting an
        // alarm late at night for the following morning.
        if (now.isBefore(alarmTimeToday)) {
          return alarmTimeToday;
        }
        final alarmTimeTomorrow = alarmTimeToday.add(const Duration(days: 1));
        return alarmTimeTomorrow;

      case RepeatType.daily:
        // Daily: next occurrence
        final start = now.isBefore(alarmTimeToday) ? today : today.add(Duration(days: 1));
        return nextAlarmDate(alarm, effectiveOverrides, from: start);

      case RepeatType.weekdays:
        // Weekdays: find next Mon-Fri
        return _findNextWeekday(alarm, effectiveOverrides, from: now);

      case RepeatType.weekends:
        // Weekends: find next Sat or Sun
        return _findNextWeekend(alarm, effectiveOverrides, from: now);

      case RepeatType.singleRest:
      case RepeatType.doubleRest:
      case RepeatType.custom:
        // Start from today if alarm time hasn't passed, else tomorrow.
        // Prevents silently skipping when the configured time for today
        // has already passed.
        final start = now.isBefore(alarmTimeToday) ? today : today.add(Duration(days: 1));
        return nextAlarmDate(alarm, effectiveOverrides, from: start);
    }
  }

  /// Calculates all trigger times within the next 7 days for the given [alarm].
  ///
  /// Returns an empty list if no triggers are found.
  static Future<List<DateTime>> calculateNext7Days(
    AlarmInfo alarm, {
    List<WeekSchedule>? overrides,
  }) async {
    final triggers = <DateTime>[];
    final first = await calculateNextTrigger(alarm, overrides: overrides);
    if (first == null) return triggers;

    final now = DateTime.now();
    final endDate = now.add(Duration(days: 7));

    var current = first;
    while (current.isBefore(endDate)) {
      triggers.add(current);
      // Calculate the next occurrence after current
      final next = await calculateNextTrigger(
        alarm.copyWith(
          hour: current.hour,
          minute: current.minute,
        ),
        overrides: overrides,
      );
      if (next == null || next.isBefore(current.add(Duration(days: 1)))) {
        break;
      }
      current = next.add(Duration(days: 1));
      // Guard against infinite loop
      if (triggers.length > 7) break;
    }

    return triggers;
  }

  /// Schedules the alarm by calculating the next trigger time and
  /// calling [AlarmNotificationService.scheduleAlarmNotification].
  ///
  /// On Android 14+, [SCHEDULE_EXACT_ALARM] permission may not be granted.
  /// This method tries exact scheduling first; if it fails, it falls back
  /// to inexact scheduling which works without special permissions.
  static Future<void> scheduleAlarm(
    AlarmInfo alarm, {
    List<WeekSchedule>? overrides,
  }) async {
    if (alarm.id == null) return;
    final nextDate = await calculateNextTrigger(alarm, overrides: overrides);
    if (nextDate == null) return;

    // combine the date with the alarm's hour:minute
    final scheduledDate = DateTime(
      nextDate.year, nextDate.month, nextDate.day,
      alarm.hour, alarm.minute, 0,
    );

    // safety: if still in the past, skip (e.g. one-time alarm already fired)
    if (scheduledDate.isBefore(DateTime.now())) return;

    try {
      await AlarmNotificationService().scheduleAlarmNotification(
        alarmId: alarm.id!,
        title: alarm.label ?? '闹钟',
        body: '到达设定时间',
        scheduledDate: scheduledDate,
        requireExact: true,
        ringtone: alarm.ringtone,
      );
    } catch (e) {
      // Android 14+ may reject exact scheduling without permission.
      // Fall back to inexact mode which works unconditionally.
      print('Exact alarm scheduling failed, falling back to inexact: $e');
      try {
        await AlarmNotificationService().scheduleAlarmNotification(
          alarmId: alarm.id!,
          title: alarm.label ?? '闹钟',
          body: '到达设定时间',
          scheduledDate: scheduledDate,
          requireExact: false,
          ringtone: alarm.ringtone,
        );
      } catch (e2) {
        print('Failed to schedule alarm ${alarm.id} (inexact too): $e2');
      }
    }
  }

  /// Cancels a previously scheduled alarm by [alarmId].
  static Future<void> cancelAlarm(int alarmId) async {
    await AlarmNotificationService().cancelAlarmNotification(alarmId);
  }

  /// Reschedules all enabled alarms from the provided list.
  ///
  /// Iterates through [alarms], filters for enabled ones, and calls
  /// [scheduleAlarm] for each. Errors for individual alarms are logged
  /// but do not prevent remaining alarms from being scheduled.
  static Future<void> rescheduleAll(
    List<AlarmInfo> alarms, {
    List<WeekSchedule>? overrides,
  }) async {
    final enabled = alarms.where((a) => a.isEnabled);
    for (final alarm in enabled) {
      try {
        await scheduleAlarm(alarm, overrides: overrides);
      } catch (e) {
        // Log and continue — don't let one bad alarm take down the rest
        print('Failed to schedule alarm ${alarm.id}: $e');
      }
    }
  }

  /// Finds the next weekday (Mon-Fri) where [shouldRingOnDate] returns true.
  static DateTime? _findNextWeekday(
    AlarmInfo alarm,
    List<WeekSchedule> overrides, {
    required DateTime from,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    for (int i = 0; i < 365; i++) {
      final candidate = start.add(Duration(days: i));
      if (candidate.weekday >= DateTime.monday &&
          candidate.weekday <= DateTime.friday &&
          shouldRingOnDate(alarm, candidate, overrides)) {
        return DateTime(
          candidate.year,
          candidate.month,
          candidate.day,
          alarm.hour,
          alarm.minute,
        );
      }
    }
    return null;
  }

  /// Finds the next weekend day (Sat or Sun) where [shouldRingOnDate] returns true.
  static DateTime? _findNextWeekend(
    AlarmInfo alarm,
    List<WeekSchedule> overrides, {
    required DateTime from,
  }) {
    final start = DateTime(from.year, from.month, from.day);
    for (int i = 0; i < 365; i++) {
      final candidate = start.add(Duration(days: i));
      if ((candidate.weekday == DateTime.saturday ||
              candidate.weekday == DateTime.sunday) &&
          shouldRingOnDate(alarm, candidate, overrides)) {
        return DateTime(
          candidate.year,
          candidate.month,
          candidate.day,
          alarm.hour,
          alarm.minute,
        );
      }
    }
    return null;
  }
}
