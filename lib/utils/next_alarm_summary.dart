import '../models/alarm_info.dart';

typedef AlarmTriggerResolver = Future<DateTime?> Function(AlarmInfo alarm);

class NextAlarm {
  final AlarmInfo alarm;
  final DateTime trigger;

  const NextAlarm({required this.alarm, required this.trigger});
}

/// Finds the earliest future trigger for enabled alarms.
///
/// Keeping selection separate from the scheduler makes the UI safe against
/// one-shot alarms that have expired and against slow holiday lookups.
Future<NextAlarm?> findNextEnabledAlarm(
  Iterable<AlarmInfo> alarms, {
  required DateTime from,
  required AlarmTriggerResolver triggerFor,
}) async {
  NextAlarm? nextAlarm;
  DateTime? nextTime;
  for (final alarm in alarms.where((alarm) => alarm.isEnabled)) {
    final trigger = await triggerFor(alarm);
    if (trigger == null || !trigger.isAfter(from)) continue;
    if (nextTime == null || trigger.isBefore(nextTime)) {
      nextTime = trigger;
      nextAlarm = NextAlarm(alarm: alarm, trigger: trigger);
    }
  }
  return nextAlarm;
}
