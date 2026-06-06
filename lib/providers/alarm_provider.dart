import 'package:flutter/foundation.dart';
import '../models/alarm_info.dart';
import '../models/week_schedule.dart';
import '../services/alarm_storage_service.dart';
import '../services/alarm_scheduler_service.dart';
import '../services/schedule_storage_service.dart';

/// ChangeNotifier managing the alarm list state.
///
/// Bridges alarm data to [AlarmSchedulerService] for scheduling and
/// persists alarm state via [AlarmStorageService].
class AlarmProvider extends ChangeNotifier {
  List<AlarmInfo> _alarms = [];
  List<AlarmInfo> get alarms => List.unmodifiable(_alarms);

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Loads all alarms from storage, reschedules enabled ones, and notifies listeners.
  Future<void> loadAlarms() async {
    try {
      _alarms = await AlarmStorageService.getAll();
      _loaded = true;
      notifyListeners();

      // Attempt to reschedule (non-critical — alarms still show even if scheduling fails)
      final overrides = await ScheduleStorageService.getAll();
      await AlarmSchedulerService.rescheduleAll(_alarms, overrides: overrides);
    } catch (e) {
      // Ensure alarms still display even if scheduling fails
      if (!_loaded) {
        _alarms = await AlarmStorageService.getAll();
        _loaded = true;
        notifyListeners();
      }
      debugPrint('loadAlarms scheduling error: $e');
    }
  }

  /// Adds a new alarm, inserts to storage.
  /// Scheduling happens implicitly via [loadAlarms].
  Future<void> addAlarm(AlarmInfo alarm) async {
    await AlarmStorageService.insert(alarm);
    await loadAlarms();
  }

  /// Updates an existing alarm and reloads (scheduling happens in loadAlarms).
  Future<void> updateAlarm(AlarmInfo alarm) async {
    await AlarmStorageService.update(alarm);
    await loadAlarms();
  }

  /// Removes the alarm with the given id, cancels its scheduler entry, and reloads.
  Future<void> removeAlarm(int id) async {
    await AlarmSchedulerService.cancelAlarm(id);
    await AlarmStorageService.delete(id);
    await loadAlarms();
  }

  /// Toggles the enabled state of the alarm and reloads.
  Future<void> toggleAlarm(int id) async {
    final alarm = _alarms.firstWhere((a) => a.id == id);
    await AlarmStorageService.toggleEnabled(id, !alarm.isEnabled);
    await loadAlarms();
  }

  /// Calculates the next trigger datetime for the given alarm.
  ///
  /// Returns `null` if no valid trigger exists within 365 days
  /// (e.g., a one-time alarm whose time has already passed).
  Future<DateTime?> nextTrigger(
    AlarmInfo alarm, {
    List<WeekSchedule>? overrides,
  }) {
    return AlarmSchedulerService.calculateNextTrigger(
      alarm,
      overrides: overrides,
    );
  }
}