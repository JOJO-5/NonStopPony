import 'package:flutter/foundation.dart';

import '../models/week_schedule.dart';
import '../services/schedule_storage_service.dart';
import '../utils/date_utils.dart';

/// ChangeNotifier managing week schedule overrides (单双休 per-week configuration).
///
/// Provides CRUD operations for [WeekSchedule] overrides and resolves
/// the effective week type for a given week using chain-linkage logic:
/// - Each override acts as an "anchor point"
/// - Weeks between anchors automatically alternate single↔double
/// - Before any override, falls back to simple odd/even parity
class ScheduleProvider extends ChangeNotifier {
  List<WeekSchedule> _overrides = [];
  List<WeekSchedule> get overrides => _overrides;

  bool _loaded = false;
  bool get loaded => _loaded;

  /// Loads all overrides from storage and marks as loaded.
  ///
  /// Wraps the storage call in try-catch so that a storage error does not
  /// leave [_loaded] as `false` forever (which would cause UI spinners to
  /// spin indefinitely).  On error the list is set to empty and the provider
  /// is still marked as loaded so the UI can render.
  Future<void> loadOverrides() async {
    try {
      _overrides = await ScheduleStorageService.getAll();
    } catch (e) {
      debugPrint('ScheduleProvider.loadOverrides error: $e');
      _overrides = [];
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  /// Sets or inserts a week type override for the given period.
  /// [weekIndex] is the absolute week number for chain-linkage.
  Future<void> setOverride(
    int year,
    int month,
    int weekOfMonth,
    WeekType weekType, {
    int? weekIndex,
  }) async {
    final wi = weekIndex ?? weekNumber(DateTime(year, month, (weekOfMonth - 1) * 7 + 1));
    final existing = await ScheduleStorageService.getByKey(year, month, weekOfMonth);
    if (existing != null) {
      final updated = existing.copyWith(weekType: weekType, weekIndex: wi);
      await ScheduleStorageService.update(updated);
    } else {
      final schedule = WeekSchedule(
        weekIndex: wi,
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
    final date = DateTime(year, month, (weekOfMonth - 1) * 7 + 1);
    final wi = weekNumber(date);
    final existing = await ScheduleStorageService.getByKey(year, month, weekOfMonth);
    final currentType = existing?.weekType ?? _autoType(year, month, weekOfMonth);
    final newType =
        currentType == WeekType.single ? WeekType.double : WeekType.single;
    await setOverride(year, month, weekOfMonth, newType, weekIndex: wi);
  }

  /// Returns the override schedule if one exists for the given period.
  Future<WeekSchedule?> getOverride(int year, int month, int weekOfMonth) {
    return ScheduleStorageService.getByKey(year, month, weekOfMonth);
  }

  /// Resolves the effective week type using chain-linkage logic.
  WeekType resolveWeekType(int year, int month, int weekOfMonth) {
    final date = DateTime(year, month, (weekOfMonth - 1) * 7 + 1);
    return resolveWeekTypeByDate(date);
  }

  /// Resolves the effective week type for a given date.
  WeekType resolveWeekTypeByDate(DateTime date) {
    final wn = weekNumber(date);

    // Check if there's an override for this exact week
    final exactOverride = _overrides.cast<WeekSchedule?>().firstWhere(
      (o) => o!.weekIndex == wn,
      orElse: () => null,
    );
    if (exactOverride != null) return exactOverride.weekType;

    // Find the nearest override BEFORE this week (the "anchor")
    final priorOverrides = _overrides
        .where((o) => o.weekIndex < wn)
        .toList()
      ..sort((a, b) => b.weekIndex.compareTo(a.weekIndex)); // descending

    if (priorOverrides.isNotEmpty) {
      final anchor = priorOverrides.first;
      final distance = wn - anchor.weekIndex;
      // Alternate from anchor: even distance = same type, odd = opposite
      if (distance.isEven) {
        return anchor.weekType;
      } else {
        return anchor.weekType == WeekType.single
            ? WeekType.double
            : WeekType.single;
      }
    }

    // No prior override → fall back to simple odd/even parity
    return autoWeekType(date);
  }

  WeekType _autoType(int year, int month, int weekOfMonth) {
    final date = DateTime(year, month, (weekOfMonth - 1) * 7 + 1);
    return autoWeekType(date);
  }

  /// Checks if a specific week has a manual override.
  bool hasOverrideForWeek(int year, int month, int weekOfMonth) {
    return _overrides.any(
      (o) => o.year == year && o.month == month && o.weekOfMonth == weekOfMonth,
    );
  }
}
