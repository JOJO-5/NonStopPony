import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'providers/alarm_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/stopwatch_provider.dart';
import 'providers/schedule_provider.dart';
import 'services/alarm_storage_service.dart';
import 'services/schedule_storage_service.dart';
import 'services/alarm_notification_service.dart';
import 'services/boot_receiver_service.dart';
import 'screens/alarm_fullscreen_screen.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database (required by flutter_local_notifications)
  // Must also set local location so tz.local reflects the device timezone,
  // otherwise zonedSchedule will use UTC and alarms won't fire at the right time.
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

  // Initialize sqflite_common_ffi for desktop platforms only.
  // On Android/iOS, sqflite uses the native implementation.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize databases
  await AlarmStorageService.init();
  await ScheduleStorageService.init();

  // Initialize notification plugin (required before scheduling any notifications)
  await AlarmNotificationService().init();

  // Request Android permissions for alarm functionality
  await AlarmNotificationService().requestAndroidPermissions();

  // Request battery optimization exemption (prevents OS from killing alarms)
  await AlarmNotificationService().requestIgnoreBatteryOptimizations();

  // Listen for MethodChannel reschedule requests from AlarmRescheduleWorker
  // (triggered on boot via WorkManager — no startActivity needed).
  const bootChannel = MethodChannel('com.example.alarm_clock/boot_receiver');
  bootChannel.setMethodCallHandler((call) async {
    if (call.method == 'rescheduleAlarms') {
      await BootReceiverService.rescheduleAlarmsAfterBoot();
    }
  });

  // Listen for alarm fire events from native AlarmReceiver/AlarmRingingService.
  // When the native AlarmManager fires, it starts AlarmRingingService and
  // may also launch the app. This channel tells Flutter to show the
  // full-screen alarm UI.
  if (Platform.isAndroid) {
    const alarmFireChannel = MethodChannel('com.example.alarm_clock/alarm_fire');
    alarmFireChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmFired') {
        final alarmId = call.arguments['alarmId'] as int? ?? -1;
        final label = call.arguments['title'] as String? ?? '战马闹钟';
        debugPrint('Received alarm fire from native: alarmId=$alarmId, label=$label');
        // Use fade-in transition instead of default slide (left→right)
        alarmNavigatorKey.currentState?.push(
          PageRouteBuilder(
            opaque: true,
            pageBuilder: (_, __, ___) => AlarmFullScreenScreen(alarmId: alarmId, label: label),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => StopwatchProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child: const AlarmClockApp(),
    ),
  );
}
