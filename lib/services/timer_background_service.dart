import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Service for scheduling/canceling a native Android AlarmManager timer
/// that fires when the countdown reaches zero, even when the app is
/// in the background or the device is in Doze mode.
///
/// This provides the "native alarm fallback" for TimerProvider:
/// - TimerProvider.start() schedules this native alarm at the end time
/// - TimerProvider.stop()/pause()/reset() cancels it
/// - When the native alarm fires, [TimerReceiver] plays a sound and
///   shows a notification without needing the Flutter engine
class TimerBackgroundService {
  static const _channel = MethodChannel('com.example.alarm_clock/timer_background');

  /// Schedules a native exact alarm at [endTimeMillis] (epoch milliseconds).
  ///
  /// When the alarm fires, [TimerReceiver] will play the alarm sound
  /// once and show a "计时完成" notification.
  static Future<void> scheduleTimerAlarm(int endTimeMillis) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('scheduleTimerAlarm', {
        'endTimeMillis': endTimeMillis,
      });
      debugPrint('TimerBackgroundService: scheduled native timer alarm at $endTimeMillis');
    } catch (e) {
      debugPrint('TimerBackgroundService: scheduleTimerAlarm failed: $e');
    }
  }

  /// Cancels any previously scheduled native timer alarm.
  static Future<void> cancelTimerAlarm() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('cancelTimerAlarm');
      debugPrint('TimerBackgroundService: canceled native timer alarm');
    } catch (e) {
      debugPrint('TimerBackgroundService: cancelTimerAlarm failed: $e');
    }
  }
}
