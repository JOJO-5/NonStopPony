import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:alarm_clock/models/alarm_info.dart';
import 'package:alarm_clock/providers/alarm_provider.dart';
import 'package:alarm_clock/providers/schedule_provider.dart';
import 'package:alarm_clock/screens/alarm_list_screen.dart';

AlarmInfo makeAlarm({int id = 1, int hour = 7, int minute = 30}) =>
    AlarmInfo.create(
      id: id,
      hour: hour,
      minute: minute,
      repeatType: RepeatType.daily,
    );

DateTime upcoming(int hour, int minute) {
  final now = DateTime.now();
  var result = DateTime(now.year, now.month, now.day, hour, minute);
  if (!result.isAfter(now)) result = result.add(const Duration(days: 1));
  return result;
}

class FakeAlarmProvider extends AlarmProvider {
  List<AlarmInfo> value = [];
  Future<DateTime?> Function(AlarmInfo alarm)? resolve;

  @override
  List<AlarmInfo> get alarms => List.unmodifiable(value);

  @override
  bool get loaded => true;

  @override
  Future<void> loadAlarms() async {}

  @override
  Future<DateTime?> nextTrigger(AlarmInfo alarm, {overrides}) {
    return resolve?.call(alarm) ?? Future.value();
  }
}

class FakeScheduleProvider extends ScheduleProvider {
  @override
  bool get loaded => true;
}

Future<void> pumpScreen(
  WidgetTester tester,
  FakeAlarmProvider alarms, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AlarmProvider>.value(value: alarms),
        ChangeNotifierProvider<ScheduleProvider>.value(
          value: FakeScheduleProvider(),
        ),
      ],
      child: const MaterialApp(home: AlarmListScreen()),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows the scheduler trigger time instead of alarm defaults', (
    tester,
  ) async {
    final provider = FakeAlarmProvider()..value = [makeAlarm()];
    provider.resolve = (_) async => upcoming(8, 45);
    await pumpScreen(tester, provider);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('08:45'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refreshes the summary after provider notification', (
    tester,
  ) async {
    final provider = FakeAlarmProvider()..value = [makeAlarm()];
    provider.resolve = (_) async => upcoming(8, 30);
    await pumpScreen(tester, provider);
    await tester.pump(const Duration(milliseconds: 50));
    provider.resolve = (_) async => upcoming(9, 30);
    provider.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('ignores a delayed result from an earlier refresh', (
    tester,
  ) async {
    final oldResult = Completer<DateTime?>();
    final provider = FakeAlarmProvider()..value = [makeAlarm()];
    provider.resolve = (_) => oldResult.future;
    await pumpScreen(tester, provider);
    await tester.pump(const Duration(milliseconds: 30));
    provider.resolve = (_) async => upcoming(9, 30);
    provider.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('09:30'), findsOneWidget);
    oldResult.complete(DateTime.now().add(const Duration(hours: 1)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('09:30'), findsOneWidget);
  });

  testWidgets('distinguishes scheduler error from no upcoming alarm', (
    tester,
  ) async {
    final provider = FakeAlarmProvider()..value = [makeAlarm()];
    provider.resolve = (_) async => throw StateError('unavailable');
    await pumpScreen(tester, provider);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('暂时无法获取下次响铃时间'), findsOneWidget);

    provider.value = [];
    provider.resolve = null;
    provider.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('暂无待响铃闹钟'), findsOneWidget);
  });

  testWidgets('empty homepage lays out at narrow phone width', (tester) async {
    final provider = FakeAlarmProvider();
    await pumpScreen(tester, provider, size: const Size(320, 640));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('暂无待响铃闹钟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
