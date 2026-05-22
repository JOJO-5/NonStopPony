import '../models/alarm_info.dart';
import '../models/week_schedule.dart';

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

/// Resolve week type: override takes priority, fallback to auto.
WeekType resolveWeekType(DateTime date, List<WeekSchedule> overrides) {
  final weekOfMonth = ((date.day - 1) ~/ 7) + 1;
  final override = overrides.cast<WeekSchedule?>().firstWhere(
    (o) =>
        o!.year == date.year && o.month == date.month && o.weekOfMonth == weekOfMonth,
    orElse: () => null,
  );
  return override?.weekType ?? autoWeekType(date);
}

/// Core function: should this alarm ring on this date?
bool shouldRingOnDate(
    AlarmInfo alarm, DateTime date, List<WeekSchedule> overrides) {
  if (!alarm.isEnabled) return false;

  switch (alarm.repeatType) {
    case RepeatType.once:
      return true;
    case RepeatType.daily:
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