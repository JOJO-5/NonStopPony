import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../screens/alarm_fullscreen_screen.dart';

/// Global navigator key so [AlarmNotificationService] can push routes without
/// a BuildContext (notification tap from background / lock screen).
final GlobalKey<NavigatorState> alarmNavigatorKey = GlobalKey<NavigatorState>();

/// MethodChannel for controlling the Android AlarmRingingService
/// (continuous alarm sound + vibration via foreground service).
const _alarmRingChannel = MethodChannel('com.example.alarm_clock/alarm_ring');

/// MethodChannel for scheduling exact alarms via Android AlarmManager.
/// This replaces flutter_local_notifications' zonedSchedule because
/// zonedSchedule only shows a notification but does NOT invoke any
/// Flutter callback — the AlarmRingingService was never started.
const _alarmSchedulerChannel = MethodChannel('com.example.alarm_clock/alarm_scheduler');

class AlarmNotificationService {
  static final AlarmNotificationService _instance =
      AlarmNotificationService._internal();
  factory AlarmNotificationService() => _instance;
  AlarmNotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const macSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macSettings,
    );
    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationResponse,
    );

    // Channel v3: created with alarm_sound so the sound attribute is locked
    // correctly on first creation (Android 8+ locks channel sound after first
    // creation — a wrong initial value cannot be changed without a new channel).
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'alarm_channel_v3',
          '战马闹钟',
          description: '战马闹钟响铃通知',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alarm_sound'),
        ),
      );
    }

    // Check if app was launched via notification (e.g. from lock screen tap)
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      _routeToAlarmScreen(payload);
    }
  }

  /// Requests Android runtime permissions critical for alarm functionality.
  ///
  /// Must be called AFTER [runApp] when an Activity context is available.
  Future<void> requestAndroidPermissions() async {
    try {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return;

      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Android permission request error: $e');
    }
  }

  /// Requests exemption from battery optimization to allow alarms to fire
  /// even when the device is in Doze mode.
  ///
  /// Only shows the system dialog if the app is NOT already on the
  /// battery optimization whitelist. This avoids the annoying repeated
  /// prompt when the user has already granted the permission.
  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return;
    try {
      // Check if already ignoring battery optimizations
      const channel = MethodChannel('com.example.alarm_clock/settings');
      final isIgnoring = await channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
      if (isIgnoring) {
        debugPrint('Already ignoring battery optimizations — skipping prompt');
        return;
      }
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.example.alarm_clock',
      );
      await intent.launch();
    } catch (e) {
      debugPrint('Battery optimization request error: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'STOP_ALARM') {
      final alarmId = int.tryParse(response.payload ?? '');
      if (alarmId != null && alarmId >= 0) {
        _plugin.cancel(id: alarmId);
      }
      // Bug #2 fix: also stop the ringing service when user taps STOP_ALARM
      stopAlarmRing();
      return;
    }
    if (response.actionId == 'snooze') {
      final alarmId = int.tryParse(response.payload ?? '');
      if (alarmId != null && alarmId >= 0) {
        snoozeAlarm(alarmId, '战马闹钟', '稍后提醒');
      }
      stopAlarmRing();
      return;
    }
    // Tapping the notification body (not the action button) opens full-screen
    _routeToAlarmScreen(response.payload);
  }

  void _routeToAlarmScreen(String? payload) {
    final alarmId = int.tryParse(payload ?? '');
    if (alarmId == null) return;

    // Use a post-frame callback so the navigator is ready.
    // Use fade-in transition instead of default slide animation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = alarmNavigatorKey.currentState;
      if (state != null && state.mounted) {
        state.push(
          PageRouteBuilder(
            opaque: true,
            pageBuilder: (_, __, ___) => AlarmFullScreenScreen(
              alarmId: alarmId,
              label: '战马闹钟',
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else {
        // Navigator not ready yet — retry after delay
        Future.delayed(const Duration(milliseconds: 500), () {
          final retryState = alarmNavigatorKey.currentState;
          if (retryState != null && retryState.mounted) {
            retryState.push(
              PageRouteBuilder(
                opaque: true,
                pageBuilder: (_, __, ___) => AlarmFullScreenScreen(
                  alarmId: alarmId,
                  label: '战马闹钟',
                ),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 300),
              ),
            );
          }
        });
      }
    });
  }

  /// Shows an immediate alarm notification.
  ///
  /// Uses [alarmId] as the notification ID so that [cancelAlarmNotification]
  /// can cancel it reliably by the same ID.
  Future<void> showAlarmNotification({
    required int alarmId,
    required String title,
    required String body,
    String ringtone = '默认',
  }) async {
    final sound = _ringtoneToSound(ringtone);
    final androidDetails = AndroidNotificationDetails(
      'alarm_channel_v3',
      '战马闹钟',
      channelDescription: '战马闹钟响铃通知',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      // Bug #3 fix: proper vibration pattern instead of all-zeros Int64List(4)
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      enableVibration: true,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      sound: sound,
      actions: [
        const AndroidNotificationAction('STOP_ALARM', '关闭',
            showsUserInterface: true),
        const AndroidNotificationAction('snooze', '稍后提醒',
            showsUserInterface: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use alarmId as notification ID — consistent with scheduleAlarmNotification.
    await _plugin.show(
      id: alarmId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: alarmId.toString(),
    );

    // Bug #2 fix: start the foreground service for continuous ringing + vibration
    startAlarmRing(ringtoneUri: ringtone);
  }

  Future<void> cancelAlarmNotification(int alarmId) async {
    // Cancel the native AlarmManager scheduled alarm
    if (Platform.isAndroid) {
      try {
        await _alarmSchedulerChannel.invokeMethod<void>('cancelExactAlarm', {
          'alarmId': alarmId,
        });
      } catch (e) {
        debugPrint('cancelExactAlarm failed: $e');
      }
    }
    // Also cancel any flutter_local_notifications notification
    try {
      await _plugin.cancel(id: alarmId);
    } catch (e) {
      debugPrint('cancelAlarmNotification failed (expected in test env): $e');
    }
    // Bug #2 fix: stop the ringing service when notification is cancelled
    stopAlarmRing();
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    // Bug #2 fix: stop the ringing service when all notifications are cancelled
    stopAlarmRing();
  }

  /// Snoozes an alarm for 5 minutes.
  ///
  /// Cancels the current notification and schedules a new one 5 minutes from now.
  Future<void> snoozeAlarm(int alarmId, String? title, String? body, {String ringtone = 'default'}) async {
    // Cancel current notification
    try {
      await _plugin.cancel(id: alarmId);
    } catch (e) {
      debugPrint('snoozeAlarm cancel failed (expected in test env): $e');
    }
    // Schedule new notification 5 minutes from now, preserving the alarm's ringtone
    final sound = _ringtoneToSound(ringtone);
    final androidDetails = AndroidNotificationDetails(
      'alarm_channel_v3',
      '战马闹钟',
      channelDescription: '战马闹钟响铃通知',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      enableVibration: true,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      sound: sound,
      actions: [
        const AndroidNotificationAction('STOP_ALARM', '关闭',
            showsUserInterface: true),
        const AndroidNotificationAction('snooze', '稍后提醒',
            showsUserInterface: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final scheduledDate = DateTime.now().add(const Duration(minutes: 5));
    await _plugin.zonedSchedule(
      id: alarmId,
      title: title ?? '战马闹钟',
      body: body ?? '稍后提醒',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: alarmId.toString(),
    );
  }

  /// Maps ringtone URI to a raw resource sound for notification channel.
  /// Only used for flutter_local_notifications fallback.
  /// The AlarmRingingService uses the URI directly via MediaPlayer.
  RawResourceAndroidNotificationSound? _ringtoneToSound(String ringtone) {
    if (ringtone == 'default' || ringtone.isEmpty) return null;
    // For system ringtones, let Android handle the sound via the notification
    // channel. We only set a custom sound for our built-in alarm_sound.
    return const RawResourceAndroidNotificationSound('alarm_sound');
  }

  /// Schedule a one-shot alarm notification at a specific date/time.
  ///
  /// Uses the native Android AlarmManager for reliable alarm delivery.
  /// When the alarm fires, [AlarmReceiver] starts [AlarmRingingService]
  /// which handles continuous sound + vibration + notification.
  ///
  /// Previously used `flutter_local_notifications` zonedSchedule, but that
  /// only shows a notification without invoking any Flutter callback,
  /// so the AlarmRingingService was never started for scheduled alarms.
  Future<void> scheduleAlarmNotification({
    required int alarmId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool requireExact = true,
    String ringtone = 'default',
  }) async {
    if (Platform.isAndroid) {
      try {
        await _alarmSchedulerChannel.invokeMethod<void>('scheduleExactAlarm', {
          'alarmId': alarmId,
          'epochMillis': scheduledDate.millisecondsSinceEpoch,
          'title': title,
          'body': body,
          'ringtoneUri': ringtone,
        });
        debugPrint('Scheduled exact alarm $alarmId via AlarmManager at $scheduledDate');
        return;
      } catch (e) {
        debugPrint('AlarmManager scheduling failed, falling back to zonedSchedule: $e');
        // Fall through to zonedSchedule as fallback
      }
    }

    // Fallback: use zonedSchedule (less reliable, notification-only)
    final sound = _ringtoneToSound(ringtone);
    final androidDetails = AndroidNotificationDetails(
      'alarm_channel_v3',
      '战马闹钟',
      channelDescription: '战马闹钟响铃通知',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      enableVibration: true,
      playSound: true,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      sound: sound,
      actions: [
        const AndroidNotificationAction('STOP_ALARM', '关闭',
            showsUserInterface: true),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id: alarmId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: details,
      androidScheduleMode: requireExact
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: alarmId.toString(),
    );
  }

  // ── Alarm Ringing Service Methods ──────────────────────────────────────

  /// Starts the Android AlarmRingingService for continuous alarm sound
  /// and vibration via a foreground service.
  ///
  /// [ringtoneUri] specifies the sound to play:
  /// - "default" → app's built-in alarm_sound.ogg
  /// - content:// URI → system ringtone or custom audio file
  static Future<void> startAlarmRing({String ringtoneUri = 'default'}) async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmRingChannel.invokeMethod<void>('startAlarmRing', {
        'ringtoneUri': ringtoneUri,
      });
    } catch (e) {
      debugPrint('startAlarmRing failed: $e');
    }
  }

  /// Stops the Android AlarmRingingService, ending the alarm sound
  /// and vibration.
  static Future<void> stopAlarmRing() async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmRingChannel.invokeMethod<void>('stopAlarmRing');
    } catch (e) {
      debugPrint('stopAlarmRing failed: $e');
    }
  }
}

/// Top-level background handler — must be a top-level or static function.
@pragma('vm:entry-point')
void _onBackgroundNotificationResponse(NotificationResponse response) {
  if (response.actionId == 'STOP_ALARM') {
    final alarmId = int.tryParse(response.payload ?? '');
    if (alarmId != null && alarmId >= 0) {
      FlutterLocalNotificationsPlugin().cancel(id: alarmId);
    }
    // Bug #2 fix: stop the ringing service in background handler too
    AlarmNotificationService.stopAlarmRing();
  } else if (response.actionId == 'snooze') {
    final alarmId = int.tryParse(response.payload ?? '');
    if (alarmId != null && alarmId >= 0) {
      AlarmNotificationService().snoozeAlarm(alarmId, '战马闹钟', '稍后提醒');
    }
    AlarmNotificationService.stopAlarmRing();
  } else {
    // Bug #2 fix: when notification fires in background, start ringing
    AlarmNotificationService.startAlarmRing();
  }
}
