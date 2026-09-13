import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:alarm_clock/services/holiday_service.dart';
import 'package:alarm_clock/services/alarm_scheduler_service.dart';
import 'package:alarm_clock/models/alarm_info.dart';
import 'package:alarm_clock/screens/settings_screen.dart';
import 'package:alarm_clock/providers/schedule_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm_clock/widgets/week_schedule_calendar.dart';

import 'alarm_list_summary_test.dart' as fixtures;

class RefreshAlarmProvider extends fixtures.FakeAlarmProvider {
  int reloads = 0;

  @override
  Future<void> loadAlarms() async {
    reloads++;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await HolidayService.createTable(db);
    HolidayService.setDatabase(db);
  });
  tearDown(() async => db.close());

  testWidgets('failed network sync does not display zero-count success', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final provider = fixtures.FakeScheduleProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider<ScheduleProvider>.value(
        value: provider,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '立即同步节假日数据'),
    );
    // Flutter's test HTTP client returns 400, exercising the real fallback path.
    await tester.runAsync(
      () => (button.onPressed! as Future<void> Function())(),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('同步完成'), findsNothing);
    expect(find.textContaining('暂无可用数据'), findsOneWidget);
    if (DateTime.now().year == 2026) {
      expect(find.textContaining('使用 39 条内置数据'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('mounted calendar refreshes holiday markers after sync', (
    tester,
  ) async {
    final provider = fixtures.FakeScheduleProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WeekScheduleCalendar(year: 2026, month: 10, provider: provider),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    expect(find.text('休'), findsNothing);

    await tester.runAsync(() async {
      await db.insert(
        'holiday_cache',
        HolidayInfo(
          date: DateTime(2026, 10, 1),
          name: '国庆节',
          isHoliday: true,
          isWorkday: false,
        ).toMap(),
      );
      HolidayService.changes.notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(find.text('休'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    HolidayService.changes.notifyListeners();
    expect(tester.takeException(), isNull);
    provider.dispose();
  });

  testWidgets('holiday update reloads alarms and next alarm summary', (
    tester,
  ) async {
    final alarms = RefreshAlarmProvider()..value = [fixtures.makeAlarm()];
    alarms.resolve = (_) async => fixtures.upcoming(8, 45);
    await fixtures.pumpScreen(tester, alarms);
    await tester.runAsync(() async => db.rawQuery('SELECT 1'));
    await tester.pump(const Duration(milliseconds: 100));
    final before = alarms.reloads;
    alarms.resolve = (_) async => fixtures.upcoming(9, 15);
    await tester.runAsync(() async {
      HolidayService.changes.notifyListeners();
      await db.rawQuery('SELECT 1');
    });
    await tester.pump(const Duration(milliseconds: 100));
    expect(alarms.reloads, before + 1);
    expect(find.text('09:15'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    HolidayService.changes.notifyListeners();
    expect(alarms.reloads, before + 1);
    expect(tester.takeException(), isNull);
    alarms.dispose();
  });

  test('restored offline holidays affect real alarm scheduling', () async {
    final alarm = AlarmInfo.create(
      hour: 7,
      minute: 30,
      repeatType: RepeatType.weekdays,
    );
    final before = await AlarmSchedulerService.calculateNextTrigger(
      alarm,
      from: DateTime(2026, 10, 1),
    );
    expect(before, DateTime(2026, 10, 1, 7, 30));
    final result = await HolidayService.syncYear(
      2026,
      fetchBody: (_) async => throw Exception('offline'),
    );
    expect(result.source, HolidayDataSource.bundled);
    expect(
      await AlarmSchedulerService.calculateNextTrigger(
        alarm,
        from: DateTime(2026, 10, 1),
      ),
      DateTime(2026, 10, 8, 7, 30),
    );
    expect(
      await AlarmSchedulerService.calculateNextTrigger(
        alarm,
        from: DateTime(2026, 10, 10),
      ),
      DateTime(2026, 10, 10, 7, 30),
    );
  });
}
