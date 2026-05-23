import 'package:flutter/material.dart';

import '../models/week_schedule.dart';
import '../providers/schedule_provider.dart';
import '../services/holiday_service.dart';
import '../utils/date_utils.dart' as alarm_utils;

/// Monthly calendar widget showing week rows with 单休/双休 type badges
/// and holiday/workday markers.
///
/// Features:
/// - Holiday days shown with green background
/// - Make-up workdays (补班) shown with orange background
/// - Chain-linkage: toggling one week automatically updates subsequent weeks
/// - Override indicator for manually-set weeks
class WeekScheduleCalendar extends StatefulWidget {
  final int year;
  final int month;
  final ScheduleProvider provider;

  const WeekScheduleCalendar({
    super.key,
    required this.year,
    required this.month,
    required this.provider,
  });

  @override
  State<WeekScheduleCalendar> createState() => _WeekScheduleCalendarState();
}

class _WeekScheduleCalendarState extends State<WeekScheduleCalendar> {
  static const _orange = Color(0xFFE8936A);
  static const _green = Color(0xFF4CAF50);

  /// Cached holiday info for the current month
  Map<String, HolidayInfo> _holidayMap = {};

  @override
  void initState() {
    super.initState();
    _loadHolidays();
  }

  @override
  void didUpdateWidget(WeekScheduleCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year || oldWidget.month != widget.month) {
      _loadHolidays();
    }
  }

  Future<void> _loadHolidays() async {
    try {
      final holidays = await HolidayService.getMonthHolidays(widget.year, widget.month);
      if (mounted) {
        setState(() {
          _holidayMap = {
            for (final h in holidays)
              h.date.toIso8601String().substring(0, 10): h
          };
        });
      }
    } catch (e) {
      debugPrint('Failed to load holidays: $e');
    }
  }

  HolidayInfo? _getHolidayInfo(DateTime day) {
    final key = day.toIso8601String().substring(0, 10);
    return _holidayMap[key];
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _buildMonthWeeks(widget.year, widget.month);

    return Column(
      children: [
        _buildDayHeader(),
        const SizedBox(height: 8),
        ...weeks.map((week) => _buildWeekRow(context, week)),
      ],
    );
  }

  /// Builds the Mon–Sun header row.
  Widget _buildDayHeader() {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const SizedBox(width: 100),
          ...labels.map((label) {
            final isWeekend = label == '六' || label == '日';
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isWeekend
                        ? _orange.withValues(alpha: 0.7)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Builds a single week row with label, badge, and day cells.
  Widget _buildWeekRow(BuildContext context, _WeekData week) {
    final weekType = widget.provider.resolveWeekType(
      widget.year,
      widget.month,
      week.weekOfMonth,
    );
    final hasOverride = widget.provider.hasOverrideForWeek(
      widget.year,
      widget.month,
      week.weekOfMonth,
    );
    final isSingle = weekType == WeekType.single;
    final badgeColor = isSingle ? _orange : _green;
    final badgeText = isSingle ? '单休' : '双休';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () => _showWeekTypeSheet(context, week.weekOfMonth, weekType),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Week label + badge column
              SizedBox(
                width: 88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第${week.weekOfMonth}周',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3D2C2C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: badgeColor,
                            ),
                          ),
                        ),
                        if (hasOverride) ...[
                          const SizedBox(width: 4),
                          const Text(
                            '(手动)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF9E9E9E),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Day cells
              ...week.days.map((day) {
                return Expanded(
                  child: _buildDayCell(day, isSingle),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single day cell with holiday/workday markers.
  Widget _buildDayCell(DateTime day, bool isSingleWeek) {
    final isCurrentMonth = day.month == widget.month;
    final isSaturday = day.weekday == DateTime.saturday;
    final isSunday = day.weekday == DateTime.sunday;
    final isWeekend = isSaturday || isSunday;
    final isToday = _isToday(day);
    final holiday = _getHolidayInfo(day);

    // Determine the cell state
    final isHoliday = holiday?.isHoliday ?? false;
    final isWorkday = holiday?.isWorkday ?? false;

    // Determine if weekend day should be dimmed (off)
    final isOff = isWeekend &&
        ((isSunday && !isWorkday) || (isSaturday && !isSingleWeek && !isWorkday));

    // Background color logic
    Color? bgColor;
    Color textColor;
    String? marker; // Small text like "休" or "班"

    if (!isCurrentMonth) {
      textColor = const Color(0xFFE0E0E0);
      marker = null;
    } else if (isHoliday) {
      // Statutory holiday — green background
      bgColor = _green.withValues(alpha: 0.12);
      textColor = _green;
      marker = '休';
    } else if (isWorkday) {
      // Make-up workday (补班) — orange background
      bgColor = _orange.withValues(alpha: 0.12);
      textColor = _orange;
      marker = '班';
    } else if (isOff) {
      textColor = const Color(0xFFBDBDBD);
      marker = null;
    } else if (isWeekend && isCurrentMonth) {
      textColor = _orange;
      marker = null;
    } else {
      textColor = const Color(0xFF3D2C2C);
      marker = null;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isToday ? 28 : null,
            height: isToday ? 28 : null,
            decoration: isToday
                ? BoxDecoration(
                    color: _orange,
                    shape: BoxShape.circle,
                  )
                : (bgColor != null
                    ? BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null),
            child: Center(
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: isToday ? Colors.white : textColor,
                ),
              ),
            ),
          ),
          // Show marker (休/班) below the day number
          if (marker != null && isCurrentMonth)
            Text(
              marker,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: textColor,
                height: 1.2,
              ),
            )
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// Shows a bottom sheet to toggle the week type.
  void _showWeekTypeSheet(
    BuildContext context,
    int weekOfMonth,
    WeekType currentType,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _WeekTypeSheet(
          year: widget.year,
          month: widget.month,
          weekOfMonth: weekOfMonth,
          currentType: currentType,
          provider: widget.provider,
        );
      },
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  /// Builds the list of weeks for the given month.
  List<_WeekData> _buildMonthWeeks(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final startWeekday = firstDay.weekday;
    final mondayOffset = startWeekday - DateTime.monday;
    final gridStart = firstDay.subtract(Duration(days: mondayOffset));

    final weeks = <_WeekData>[];
    var weekStart = gridStart;
    var weekIndex = 1;

    while (true) {
      final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
      final hasMonthDay = days.any((d) => d.month == month && d.year == year);
      if (!hasMonthDay && weekIndex > 1) break;
      if (weekIndex > 6) break;

      weeks.add(_WeekData(
        weekOfMonth: weekIndex,
        days: days,
      ));
      weekStart = weekStart.add(const Duration(days: 7));
      weekIndex++;
    }

    return weeks;
  }
}

class _WeekData {
  final int weekOfMonth;
  final List<DateTime> days;

  _WeekData({required this.weekOfMonth, required this.days});
}

/// Bottom sheet for toggling week type between auto/单休/双休.
class _WeekTypeSheet extends StatelessWidget {
  final int year;
  final int month;
  final int weekOfMonth;
  final WeekType currentType;
  final ScheduleProvider provider;

  const _WeekTypeSheet({
    required this.year,
    required this.month,
    required this.weekOfMonth,
    required this.currentType,
    required this.provider,
  });

  static const _orange = Color(0xFFE8936A);
  static const _green = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final autoType = alarm_utils.autoWeekType(
      DateTime(year, month, (weekOfMonth - 1) * 7 + 1),
    );
    final hasOverride = provider.hasOverrideForWeek(year, month, weekOfMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            '第$weekOfMonth周 日程设置',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D2C2C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '自动类型：${alarm_utils.weekTypeLabel(autoType)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '切换后，后续周将自动联动调整',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF5C8AE6),
            ),
          ),
          const SizedBox(height: 20),
          _buildOption(
            context: context,
            label: '单休',
            subtitle: '周六上班，周日休息',
            color: _orange,
            isSelected: currentType == WeekType.single,
            onTap: () => _selectType(context, WeekType.single),
          ),
          const SizedBox(height: 12),
          _buildOption(
            context: context,
            label: '双休',
            subtitle: '周六周日都休息',
            color: _green,
            isSelected: currentType == WeekType.double,
            onTap: () => _selectType(context, WeekType.double),
          ),
          if (hasOverride) ...[
            const SizedBox(height: 12),
            _buildResetOption(context),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required String label,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: color, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFBDBDBD),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? color : const Color(0xFF3D2C2C),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetOption(BuildContext context) {
    return GestureDetector(
      onTap: () => _resetToAuto(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.restore, size: 18, color: Color(0xFF9E9E9E)),
            SizedBox(width: 12),
            Text(
              '恢复自动（后续周也会联动重算）',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9E9E9E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectType(BuildContext context, WeekType type) async {
    await provider.setOverride(year, month, weekOfMonth, type);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _resetToAuto(BuildContext context) async {
    await provider.removeOverride(year, month, weekOfMonth);
    if (context.mounted) Navigator.of(context).pop();
  }
}
