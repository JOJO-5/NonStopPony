import 'package:flutter/foundation.dart';

import '../models/alarm_info.dart';
import '../models/week_schedule.dart';
import '../utils/date_utils.dart';
import 'alarm_notification_service.dart';
import 'holiday_service.dart';

/// Service for calculating next alarm trigger times and managing alarm scheduling.
///
/// Integrates with [shouldRingOnDate] and [nextAlarmDate] from date_utils
/// to handle the 单双休 (alternating single/double weekend) scheduling logic.
class AlarmSchedulerService {
  AlarmSchedulerService._();

  /// Calculates the next trigger [DateTime] for the given [alarm].
  ///
  /// Returns `null` if no valid trigger date is found within 365 days.
  /// Optional [from] sets the search start point (defaults to now).
  ///
  /// Now integrates with [HolidayService] to check statutory holidays
  /// (rest days → don't ring) and make-up workdays (补班 → ring).
  static Future<DateTime?> calculateNextTrigger(
    AlarmInfo alarm, {
    List<WeekSchedule>? overrides,
    DateTime? from,
  }) async {
    final effectiveOverrides = overrides ?? [];
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Today's holiday status (needed for the once / start-day decision)
    bool todayIsHoliday = false;
    bool todayIsWorkday = false;
    try {
      final info = await HolidayService.getHolidayInfo(today);
      todayIsHoliday = info?.isHoliday ?? false;
      todayIsWorkday = info?.isWorkday ?? false;
    } catch (e) {
      debugPrint('Holiday check failed for today: $e');
    }
    final alarmTimeToday = alarmTimeForDate(alarm, today, effectiveOverrides,
        isWorkday: todayIsWorkday);

    // Start date for search
    DateTime start;
    switch (alarm.repeatType) {
      case RepeatType.once:
        // One-time alarm: honor the weekdays filter too. A once alarm
        // with weekdays=[Saturday] must not fire today if today is not
        // Saturday, even if the time-of-day has not yet passed.
        final todayRings = shouldRingOnDate(alarm, today, effectiveOverrides,
            isHoliday: todayIsHoliday, isWorkday: todayIsWorkday);
        if (todayRings && now.isBefore(alarmTimeToday)) {
          return alarmTimeToday;
        }
        // today was a valid ring day but the time already passed OR
        // today is not a ring day. Either way, a one-time alarm never
        // re-fires, so there is no future trigger.
        return null;
      default:
        start = now.isBefore(alarmTimeToday)
            ? today
            : today.add(const Duration(days: 1));
    }

    // Search with holiday/workday checks
    for (int i = 0; i < 365; i++) {
      final candidate = start.add(Duration(days: i));

      // Check holiday/workday status (single query, both flags)
      HolidayInfo? info;
      try {
        info = await HolidayService.getHolidayInfo(candidate);
      } catch (e) {
        debugPrint('Holiday check failed for $candidate: $e');
      }
      final isHoliday = info?.isHoliday ?? false;
      final isWorkday = info?.isWorkday ?? false;

      if (shouldRingOnDate(alarm, candidate, effectiveOverrides,
          isHoliday: isHoliday, isWorkday: isWorkday)) {
        return alarmTimeForDate(alarm, candidate, effectiveOverrides,
            isWorkday: isWorkday);
      }
    }
    return null;
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
      // One-time alarms have at most one future trigger.
      if (alarm.repeatType == RepeatType.once) break;
      // Search for the next occurrence starting from the day after current
      final nextDay = DateTime(current.year, current.month, current.day)
          .add(const Duration(days: 1));
      final next = await calculateNextTrigger(
        alarm,
        overrides: overrides,
        from: nextDay,
      );
      if (next == null || !next.isAfter(current)) {
        break;
      }
      current = next;
      // Guard against infinite loop
      if (triggers.length >= 7) break;
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

    // nextDate already carries the correct trigger time-of-day.
    // safety: if still in the past, skip (e.g. one-time alarm already fired)
    if (nextDate.isBefore(DateTime.now())) return;

    try {
      await AlarmNotificationService().scheduleAlarmNotification(
        alarmId: alarm.id!,
        title: alarm.label ?? '闹钟',
        body: '到达设定时间',
        scheduledDate: nextDate,
        requireExact: true,
        ringtone: alarm.ringtone,
      );
    } catch (e) {
      // Android 14+ may reject exact scheduling without permission.
      // Fall back to inexact mode which works unconditionally.
      debugPrint('Exact alarm scheduling failed, falling back to inexact: $e');
      try {
        await AlarmNotificationService().scheduleAlarmNotification(
          alarmId: alarm.id!,
          title: alarm.label ?? '闹钟',
          body: '到达设定时间',
          scheduledDate: nextDate,
          requireExact: false,
          ringtone: alarm.ringtone,
        );
      } catch (e2) {
        debugPrint('Failed to schedule alarm ${alarm.id} (inexact too): $e2');
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
        debugPrint('Failed to schedule alarm ${alarm.id}: $e');
      }
    }
  }

}
