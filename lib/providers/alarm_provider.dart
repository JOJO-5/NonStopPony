import 'dart:async';

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

      // Cancel any armed native alarms for disabled entries. Without this,
      // toggling a switch off leaves the previously scheduled AlarmManager
      // entry alive and the alarm still rings.
      for (final alarm in _alarms) {
        if (!alarm.isEnabled && alarm.id != null) {
          await AlarmSchedulerService.cancelAlarm(alarm.id!);
        }
      }
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
  ///
  /// Concurrent toggleAlarm calls are serialized via [_toggleQueue] so the
  /// second call reads the DB state committed by the first call instead of
  /// the stale in-memory copy. Without serialization, two rapid taps could
  /// both flip the same source value, leaving the alarm in an unintended
  /// final state.
  Future<void> _toggleQueue = Future.value();

  Future<void> toggleAlarm(int id) async {
    final completer = Completer<void>();
    final previous = _toggleQueue;
    _toggleQueue = completer.future;
    try {
      await previous;
      // Read canonical state from DB rather than _alarms, so we always
      // flip the most recently committed value.
      final current = await AlarmStorageService.getById(id);
      if (current == null) return;
      await AlarmStorageService.toggleEnabled(id, !current.isEnabled);
      await loadAlarms();
    } finally {
      completer.complete();
    }
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