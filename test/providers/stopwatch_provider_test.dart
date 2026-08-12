import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/providers/stopwatch_provider.dart';

void main() {
  test('超过 1 小时显示 HH:MM:SS.cc 而非回绕', () {
    expect(
        StopwatchProvider.format(
            const Duration(minutes: 90, seconds: 5, milliseconds: 120)),
        '01:30:05.12');
    expect(
        StopwatchProvider.format(
            const Duration(minutes: 3, seconds: 5, milliseconds: 120)),
        '03:05.12');
    expect(StopwatchProvider.format(Duration.zero), '00:00.00');
  });
}
