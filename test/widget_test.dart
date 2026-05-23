import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_clock/models/alarm_info.dart';
import 'package:alarm_clock/models/week_schedule.dart';

void main() {
  testWidgets('AlarmInfo model smoke test', (WidgetTester tester) async {
    final alarm = AlarmInfo.create(hour: 7, minute: 30);
    expect(alarm.hour, 7);
    expect(alarm.minute, 30);
    expect(alarm.repeatType, RepeatType.once);
    expect(alarm.isEnabled, true);
  });

  testWidgets('WeekSchedule model smoke test', (WidgetTester tester) async {
    final schedule = WeekSchedule(
      weekIndex: 1,
      year: 2026,
      month: 5,
      weekOfMonth: 3,
      weekType: WeekType.single,
    );
    expect(schedule.year, 2026);
    expect(schedule.weekType, WeekType.single);
  });
}
