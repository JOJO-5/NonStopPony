import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:alarm_clock/app.dart';
import 'package:alarm_clock/providers/schedule_provider.dart';
import 'package:alarm_clock/services/alarm_storage_service.dart';
import 'package:alarm_clock/widgets/alarm_tile.dart';
import 'package:alarm_clock/models/alarm_info.dart';

/// Host-side render checks for the warm-sunrise UI: the alarm tile must lay
/// out cleanly at phone width for every repeat type (no overflow / build
/// errors). Device-free guard against layout regressions.
void main() {
  late Directory tempDir;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    GoogleFonts.config.allowRuntimeFetching = false;
    tempDir = await Directory.systemTemp.createTemp('ui_tile');
    await AlarmStorageService.init(databasePath: tempDir.path);
  });

  tearDownAll(() async {
    try {
      await AlarmStorageService.close();
    } catch (_) {}
  });

  Future<void> pumpTile(WidgetTester tester, AlarmInfo alarm) async {
    tester.view.physicalSize = const Size(1200, 2700);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider(create: (_) => ScheduleProvider())],
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: kBrandWarmBg,
            body: Center(
              child: AlarmTile(alarm: alarm, onToggle: () {}, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  AlarmInfo alarmOf(RepeatType type, {bool enabled = true, String? label}) => AlarmInfo(
        hour: 7,
        minute: 30,
        repeatType: type,
        weekdays: const [1, 2, 3, 4, 5, 6],
        label: label,
        vibrate: true,
        snoozeMinutes: 5,
        isEnabled: enabled,
      );

  testWidgets('alarm tile lays out at phone width', (tester) async {
    await pumpTile(tester, alarmOf(RepeatType.daily, label: '\u8d77\u5e8a\u4e0a\u73ed'));
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('\u8d77\u5e8a\u4e0a\u73ed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alarm tile renders singleRest + disabled variants', (tester) async {
    await pumpTile(tester, alarmOf(RepeatType.singleRest));
    expect(tester.takeException(), isNull);

    await pumpTile(tester, alarmOf(RepeatType.once, enabled: false));
    expect(tester.takeException(), isNull);
  });
}
