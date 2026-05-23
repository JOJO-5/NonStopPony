import 'package:flutter/foundation.dart';

import 'alarm_storage_service.dart';
import 'alarm_scheduler_service.dart';

/// Service that reschedules alarms after device reboot.
///
/// The reschedule flag is intentionally NOT persisted to disk — that's okay:
/// - On normal app launch, loadAlarms() in AlarmProvider always reschedules.
/// - On reboot, BootReceiver uses WorkManager → AlarmRescheduleWorker which
///   invokes rescheduleAlarmsAfterBoot() via MethodChannel.
/// - There is no dual-path conflict because WorkManager fires only on reboot,
///   while the normal app launch path fires only when the user opens the app.
class BootReceiverService {
  /// Reschedules all enabled alarms. Safe to call multiple times — duplicate
  /// zonedSchedule calls with the same alarmId simply replace the old entry
  /// in Android AlarmManager, which is idempotent.
  static Future<void> rescheduleAlarmsAfterBoot() async {
    try {
      final alarms = await AlarmStorageService.getAll();
      await AlarmSchedulerService.rescheduleAll(
        alarms.where((a) => a.isEnabled).toList(),
      );
    } catch (e) {
      debugPrint('BootReceiverService.rescheduleAlarmsAfterBoot error: $e');
    }
  }
}
