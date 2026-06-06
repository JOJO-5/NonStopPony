import '../models/alarm_info.dart';
import '../models/week_schedule.dart';

/// Returns the effective trigger DateTime for an [alarm] on a given [date].
/// For singleRest alarms on a single-rest Saturday, uses [alarm.saturdayHour]
/// and [alarm.saturdayMinute]; otherwise uses the alarm's base time.
DateTime alarmTimeForDate(AlarmInfo alarm, DateTime date, List<WeekSchedule> overrides) {
  if (alarm.repeatType == RepeatType.singleRest &&
      date.weekday == DateTime.saturday) {
    final wt = resolveWeekType(date, overrides);
    if (wt == WeekType.single) {
      return DateTime(date.year, date.month, date.day, alarm.saturdayHour, alarm.saturdayMinute);
    }
  }
  return DateTime(date.year, date.month, date.day, alarm.hour, alarm.minute);
}

/// Calculate ISO week number since Jan 1, 2024 as epoch.
/// Uses simple week counting from epoch, not ISO week-of-year.
int weekNumber(DateTime date) {
  final epoch = DateTime(2024, 1, 1);
  final diff = date.difference(epoch);
  return diff.inDays ~/ 7 + 1;
}

/// Determine auto week type based on even/odd week parity.
/// Odd week number = singleRest (单休), even = doubleRest (双休).
WeekType autoWeekType(DateTime date) {
  return weekNumber(date).isOdd ? WeekType.single : WeekType.double;
}

/// Resolve week type with **chain-linkage** logic:
///
/// Overrides form "anchor points" in the single↔double chain.
/// Between two overrides, weeks alternate starting from the first override.
/// Before any override, fall back to simple odd/even parity.
///
/// Example: overrides at week 5=single, week 10=double
///   weeks 1-4: auto parity
///   week 5: single (override)
///   week 6: double (chain from week 5)
///   week 7: single (chain from week 5)
///   week 8: double (chain from week 5)
///   week 9: single (chain from week 5)
///   week 10: double (override) ← breaks the chain
///   week 11: single (chain from week 10)
///   ...
WeekType resolveWeekType(DateTime date, List<WeekSchedule> overrides) {
  final wn = weekNumber(date);

  // Check if there's an override for this exact week
  final exactOverride = overrides.cast<WeekSchedule?>().firstWhere(
    (o) => o!.weekIndex == wn,
    orElse: () => null,
  );
  if (exactOverride != null) return exactOverride.weekType;

  // Find the nearest override BEFORE this week (the "anchor")
  final priorOverrides = overrides
      .where((o) => o.weekIndex < wn)
      .toList()
    ..sort((a, b) => b.weekIndex.compareTo(a.weekIndex)); // descending

  if (priorOverrides.isNotEmpty) {
    final anchor = priorOverrides.first;
    final distance = wn - anchor.weekIndex;
    // Alternate from anchor: even distance = same type, odd distance = opposite
    if (distance.isEven) {
      return anchor.weekType;
    } else {
      return anchor.weekType == WeekType.single
          ? WeekType.double
          : WeekType.single;
    }
  }

  // No prior override → fall back to simple odd/even parity
  return autoWeekType(date);
}

/// Core function: should this alarm ring on this date?
///
/// Integrates with:
/// 1. Holiday API — statutory holidays don't ring, make-up workdays (补班) ring
/// 2. Week schedule overrides — singleRest weeks ring on Saturday
/// 3. Standard repeat rules
///
/// [holidayInfo] is optional; if null, no holiday logic is applied.
bool shouldRingOnDate(
    AlarmInfo alarm, DateTime date, List<WeekSchedule> overrides,
    {bool? isHoliday, bool? isWorkday}) {
  if (!alarm.isEnabled) return false;

  // ── Holiday/workday override (highest priority) ──
  // If this day is a statutory holiday (假期), never ring
  if (isHoliday == true) return false;
  // If this day is a make-up workday (补班), always ring
  if (isWorkday == true) return true;

  switch (alarm.repeatType) {
    case RepeatType.once:
      // If weekdays are specified, only ring on those weekdays
      if (alarm.weekdays.isNotEmpty) {
        return alarm.weekdays.contains(date.weekday);
      }
      return true;
    case RepeatType.daily:
      // Daily respects weekdays if specified; otherwise rings every day
      if (alarm.weekdays.isNotEmpty) {
        return alarm.weekdays.contains(date.weekday);
      }
      return true;
    case RepeatType.weekdays:
      return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
    case RepeatType.weekends:
      return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    case RepeatType.singleRest:
      if (date.weekday == DateTime.sunday) return false;
      if (date.weekday != DateTime.saturday) return true;
      final wt = resolveWeekType(date, overrides);
      return wt == WeekType.single;
    case RepeatType.doubleRest:
      // Both Saturday and Sunday always off for doubleRest
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        return false;
      }
      return true;
    case RepeatType.custom:
      return alarm.weekdays.contains(date.weekday);
  }
}

/// Find next DateTime where shouldRingOnDate returns true.
/// Search starts from `from` (default: now). Limits search to 365 days.
/// Synchronous version — does NOT check holidays (use [nextAlarmDateAsync] for that).
DateTime? nextAlarmDate(
  AlarmInfo alarm,
  List<WeekSchedule> overrides, {
  DateTime? from,
}) {
  final start = from ?? DateTime.now();
  for (int i = 0; i < 365; i++) {
    final candidate = DateTime(start.year, start.month, start.day + i);
    if (shouldRingOnDate(alarm, candidate, overrides)) {
      return candidate;
    }
  }
  return null;
}

/// Async version: find next alarm date with holiday/workday checks.
Future<DateTime?> nextAlarmDateAsync(
  AlarmInfo alarm,
  List<WeekSchedule> overrides, {
  DateTime? from,
  required Future<bool?> Function(DateTime) isHolidayFn,
  required Future<bool?> Function(DateTime) isWorkdayFn,
}) async {
  final start = from ?? DateTime.now();
  for (int i = 0; i < 365; i++) {
    final candidate = DateTime(start.year, start.month, start.day + i);
    final isH = await isHolidayFn(candidate);
    final isW = await isWorkdayFn(candidate);
    if (shouldRingOnDate(alarm, candidate, overrides,
        isHoliday: isH, isWorkday: isW)) {
      return candidate;
    }
  }
  return null;
}

/// Returns Chinese label for week type.
String weekTypeLabel(WeekType wt) {
  return wt == WeekType.single ? '单休' : '双休';
}

/// Returns Chinese label for weekday (1=星期一, 7=星期日).
String dayLabel(int weekday) {
  const labels = [
    '',
    '星期一',
    '星期二',
    '星期三',
    '星期四',
    '星期五',
    '星期六',
    '星期日',
  ];
  return labels[weekday];
}

/// Returns which week of the month this date falls in (1-based).
int weekOfMonth(DateTime date) {
  return ((date.day - 1) ~/ 7) + 1;
}

/// Returns the 7 DateTimes for a given year+month+weekOfMonth.
/// Week 1 = days 1-7, Week 2 = days 8-14, etc.
List<DateTime> getWeekDays(int year, int month, int weekOfMonth) {
  final startDay = (weekOfMonth - 1) * 7 + 1;
  return List.generate(7, (i) => DateTime(year, month, startDay + i));
}