import 'package:flutter/foundation.dart';

import '../models/week_schedule.dart';
import '../services/schedule_storage_service.dart';
import '../utils/date_utils.dart';

/// ChangeNotifier managing week schedule overrides (单双休 per-week configuration).
///
/// Provides CRUD operations for [WeekSchedule] overrides and resolves
/// the effective week type for a given year/month/week combination.
class ScheduleProvider extends ChangeNotifier {
  List<WeekSchedule> _overrides = [];
  List<WeekSchedule> get overrides => _overrides;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Loads all overrides from storage and marks as loaded.
  Future<void> loadOverrides() async {
    _overrides = await ScheduleStorageService.getAll();
    _loaded = true;
    notifyListeners();
  }

  /// Sets or inserts a week type override for the given period.
  Future<void> setOverride(
    int year,
    int month,
    int weekOfMonth,
    WeekType weekType,
  ) async {
    final existing = await ScheduleStorageService.getByKey(year, month, weekOfMonth);
    if (existing != null) {
      final updated = existing.copyWith(weekType: weekType);
      await ScheduleStorageService.update(updated);
    } else {
      final schedule = WeekSchedule(
        year: year,
        month: month,
        weekOfMonth: weekOfMonth,
        weekType: weekType,
      );
      await ScheduleStorageService.insert(schedule);
    }
    await loadOverrides();
  }

  /// Removes the override for the given period.
  Future<void> removeOverride(int year, int month, int weekOfMonth) async {
    await ScheduleStorageService.deleteByKey(year, month, weekOfMonth);
    await loadOverrides();
  }

  /// Toggles the week type between single and double for the given period.
  Future<void> toggleWeekType(int year, int month, int weekOfMonth) async {
    final existing = await ScheduleStorageService.getByKey(year, month, weekOfMonth);
    final currentType = existing?.weekType ?? _autoType(year, month, weekOfMonth);
    final newType =
        currentType == WeekType.single ? WeekType.double : WeekType.single;
    await setOverride(year, month, weekOfMonth, newType);
  }

  /// Returns the override schedule if one exists for the given period.
  Future<WeekSchedule?> getOverride(int year, int month, int weekOfMonth) {
    return ScheduleStorageService.getByKey(year, month, weekOfMonth);
  }

  /// Resolves the effective week type: override takes priority,
  /// falls back to the auto-determined type based on week parity.
  WeekType resolveWeekType(int year, int month, int weekOfMonth) {
    final override = _overrides.cast<WeekSchedule?>().firstWhere(
      (o) =>
          o!.year == year && o.month == month && o.weekOfMonth == weekOfMonth,
      orElse: () => null,
    );
    if (override != null) return override.weekType;

    // Fallback to auto parity: construct a representative DateTime
    final date = DateTime(year, month, (weekOfMonth - 1) * 7 + 1);
    return autoWeekType(date);
  }

  WeekType _autoType(int year, int month, int weekOfMonth) {
    final date = DateTime(year, month, (weekOfMonth - 1) * 7 + 1);
    return autoWeekType(date);
  }
}
