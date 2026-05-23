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
import 'services/alarm_notification_service.dart';
import 'services/boot_receiver_service.dart';
import 'services/holiday_service.dart';
import 'screens/alarm_fullscreen_screen.dart';
import 'screens/timer_fullscreen_screen.dart';
import 'app.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pending alarm navigation — handles the timing issue where fullScreenIntent
// launches the app before Flutter's Navigator is ready.
// ─────────────────────────────────────────────────────────────────────────────

/// Cached alarm navigation request when Navigator isn't ready yet.
_AlarmNavigation? _pendingAlarmNav;

/// Whether a timer full-screen navigation is pending.
bool _pendingTimerNav = false;

/// Holds alarm info for deferred navigation.
class _AlarmNavigation {
  final int alarmId;
  final String label;
  _AlarmNavigation(this.alarmId, this.label);
}

/// Try to navigate to the full-screen alarm screen.
/// If Navigator isn't ready, cache the request for later.
void _navigateToAlarmScreen(int alarmId, String label) {
  final state = alarmNavigatorKey.currentState;
  if (state != null && state.mounted) {
    _pushAlarmScreen(state, alarmId, label);
    _pendingAlarmNav = null;
  } else {
    debugPrint('Navigator not ready, caching alarm navigation: alarmId=$alarmId');
    _pendingAlarmNav = _AlarmNavigation(alarmId, label);
    // Retry after a short delay — Navigator may become ready soon
    Future.delayed(const Duration(milliseconds: 500), () => _checkPendingAlarm());
  }
}

/// Try to navigate to the full-screen timer screen.
/// If Navigator isn't ready, cache the request for later.
void _navigateToTimerScreen() {
  final state = alarmNavigatorKey.currentState;
  if (state != null && state.mounted) {
    TimerFullScreenScreen.push(state.context);
    _pendingTimerNav = false;
  } else {
    debugPrint('Navigator not ready, caching timer navigation');
    _pendingTimerNav = true;
    Future.delayed(const Duration(milliseconds: 500), () => _checkPendingTimer());
  }
}

/// Push the alarm full-screen route onto the navigator.
void _pushAlarmScreen(NavigatorState state, int alarmId, String label) {
  state.push(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => AlarmFullScreenScreen(alarmId: alarmId, label: label),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

/// Check and execute any pending alarm navigation.
void _checkPendingAlarm() {
  final pending = _pendingAlarmNav;
  if (pending == null) return;

  final state = alarmNavigatorKey.currentState;
  if (state != null && state.mounted) {
    debugPrint('Executing pending alarm navigation: alarmId=${pending.alarmId}');
    _pushAlarmScreen(state, pending.alarmId, pending.label);
    _pendingAlarmNav = null;
  } else {
    // Still not ready — retry again after another delay
    debugPrint('Navigator still not ready, will retry pending alarm navigation');
    Future.delayed(const Duration(milliseconds: 500), () => _checkPendingAlarm());
  }
}

/// Check and execute any pending timer navigation.
void _checkPendingTimer() {
  if (!_pendingTimerNav) return;

  final state = alarmNavigatorKey.currentState;
  if (state != null && state.mounted) {
    debugPrint('Executing pending timer navigation');
    TimerFullScreenScreen.push(state.context);
    _pendingTimerNav = false;
  } else {
    debugPrint('Navigator still not ready, will retry pending timer navigation');
    Future.delayed(const Duration(milliseconds: 500), () => _checkPendingTimer());
  }
}

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

  // Initialize databases (ScheduleStorageService shares AlarmStorageService's DB)
  await AlarmStorageService.init();

  // Fetch and cache statutory holiday data (current + next year)
  // Non-blocking: runs in background so app startup is not delayed
  HolidayService.ensureCurrentData().catchError((e) {
    debugPrint('Holiday data fetch failed (will retry later): $e');
  });

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
  //
  // CRITICAL: The fullScreenIntent may launch the app before Flutter's
  // Navigator is ready. We cache pending navigation and retry later.
  if (Platform.isAndroid) {
    const alarmFireChannel = MethodChannel('com.example.alarm_clock/alarm_fire');
    alarmFireChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmFired') {
        final alarmId = call.arguments['alarmId'] as int? ?? -1;
        final label = call.arguments['title'] as String? ?? '战马闹钟';
        debugPrint('Received alarm fire from native: alarmId=$alarmId, label=$label');
        _navigateToAlarmScreen(alarmId, label);
      }
    });

    // Timer fire channel: native TimerRingingService tells Flutter to show
    // the timer full-screen UI via fullScreenIntent.
    const timerFireChannel = MethodChannel('com.example.alarm_clock/timer_fire');
    timerFireChannel.setMethodCallHandler((call) async {
      if (call.method == 'onTimerFired') {
        debugPrint('Received timer fire from native');
        _navigateToTimerScreen();
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
