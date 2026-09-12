import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_clock/models/alarm_info.dart';
import 'package:alarm_clock/utils/next_alarm_summary.dart';

void main() {
  AlarmInfo alarm(int id, {bool enabled = true}) => AlarmInfo.create(
    id: id,
    hour: 7,
    minute: id,
    repeatType: RepeatType.daily,
    isEnabled: enabled,
  );

  test('selects the soonest future trigger among enabled alarms', () async {
    final now = DateTime(2026, 9, 12, 6);
    final result = await findNextEnabledAlarm(
      [alarm(1), alarm(2)],
      from: now,
      triggerFor: (a) async => now.add(Duration(hours: a.id == 1 ? 3 : 1)),
    );

    expect(result?.alarm.id, 2);
    expect(result?.trigger, now.add(const Duration(hours: 1)));
  });

  test('ignores disabled alarms and stale or missing triggers', () async {
    final now = DateTime(2026, 9, 12, 6);
    final result = await findNextEnabledAlarm(
      [alarm(1, enabled: false), alarm(2), alarm(3)],
      from: now,
      triggerFor: (a) async {
        if (a.id == 2) return now.subtract(const Duration(minutes: 1));
        if (a.id == 3) return null;
        return now.add(const Duration(hours: 1));
      },
    );

    expect(result, isNull);
  });
}
