import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm_info.dart';
import '../providers/alarm_provider.dart';
import '../widgets/repeat_picker.dart';
import '../screens/ringtone_picker_screen.dart';
import '../app.dart';

class AddEditAlarmScreen extends StatefulWidget {
  final AlarmInfo? alarm;
  const AddEditAlarmScreen({super.key, this.alarm});

  @override
  State<AddEditAlarmScreen> createState() => _AddEditAlarmScreenState();
}

class _AddEditAlarmScreenState extends State<AddEditAlarmScreen> {
  late int _hour, _minute;
  late int _saturdayHour, _saturdayMinute;
  late List<int> _selectedDays;
  late RepeatType _repeatType;
  late TextEditingController _labelController;
  late String _ringtone;       // URI
  late String _ringtoneTitle;  // Display name
  late AlarmTaskType _taskType;
  bool _saving = false;

  /// Fixed extent controllers for the hour and minute pickers.
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _satHourController;
  late FixedExtentScrollController _satMinuteController;

  bool get _isEditing => widget.alarm != null;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _hour = a?.hour ?? 7;
    _minute = a?.minute ?? 0;
    _saturdayHour = a?.saturdayHour ?? 8;
    _saturdayMinute = a?.saturdayMinute ?? 0;
    _selectedDays = a != null ? List<int>.from(a.weekdays) : [];
    _repeatType = a?.repeatType ?? RepeatType.once;
    _labelController = TextEditingController(text: a?.label ?? '');
    _ringtone = a?.ringtone ?? 'default';
    _ringtoneTitle = a?.ringtoneTitle ?? '默认';
    _taskType = a?.taskType ?? AlarmTaskType.none;

    // Initialise scroll controllers so the wheels start at the correct value.
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _satHourController = FixedExtentScrollController(initialItem: _saturdayHour);
    _satMinuteController = FixedExtentScrollController(initialItem: _saturdayMinute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _satHourController.dispose();
    _satMinuteController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final alarm = AlarmInfo.create(
        id: widget.alarm?.id,
        hour: _hour,
        minute: _minute,
        repeatType: _repeatType,
        weekdays: _selectedDays,
        label: _labelController.text.isEmpty ? null : _labelController.text,
        ringtone: _ringtone,
        ringtoneTitle: _ringtoneTitle,
        saturdayHour: _saturdayHour,
        saturdayMinute: _saturdayMinute,
        taskType: _taskType,
      );
      final provider = context.read<AlarmProvider>();
      if (_isEditing) {
        await provider.updateAlarm(alarm);
      } else {
        await provider.addAlarm(alarm);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Opens the full-screen ringtone picker page
  Future<void> _showRingtonePicker() async {
    final result = await Navigator.push<RingtoneSelection>(
      context,
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => RingtonePickerScreen(
          currentRingtone: _ringtone,
          currentRingtoneTitle: _ringtoneTitle,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _ringtone = result.uri;
        _ringtoneTitle = result.title;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: kBrandWarmBg,
      appBar: AppBar(
        title: Text(_isEditing ? '\u7f16\u8f91\u95f9\u949f' : '\u65b0\u5efa\u95f9\u949f'),
        backgroundColor: kBrandWarmBg,
        foregroundColor: kBrandTextPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: kSpace5, vertical: kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Roller-style time picker ───────────────────
            _SectionCard(
              child: Column(
                children: [
                  const Text(
                    '\u65f6\u95f4',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBrandTextSecondary),
                  ),
                  const SizedBox(height: kSpace4),
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        // Hour wheel
                        Expanded(
                          child: _TimeWheel(
                            controller: _hourController,
                            itemCount: 24,
                            initialValue: _hour,
                            onSelectedItemChanged: (index) {
                              setState(() => _hour = index);
                            },
                          ),
                        ),
                        // Colon separator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              color: kBrandCopper,
                              height: 1.0,
                            ),
                          ),
                        ),
                        // Minute wheel
                        Expanded(
                          child: _TimeWheel(
                            controller: _minuteController,
                            itemCount: 60,
                            initialValue: _minute,
                            onSelectedItemChanged: (index) {
                              setState(() => _minute = index);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: kSpace2),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kBrandTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: kSpace3),

            // ── Saturday time picker (only for singleRest) ──
            if (_repeatType == RepeatType.singleRest)
              _SectionCard(
                child: Column(
                  children: [
                    const Text('周六起床时间（单休周）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBrandCopper)),
                    const SizedBox(height: kSpace2),
                    SizedBox(
                      height: 160,
                      child: Row(
                        children: [
                          Expanded(
                            child: _TimeWheel(
                              controller: _satHourController,
                              itemCount: 24,
                              initialValue: _saturdayHour,
                              onSelectedItemChanged: (i) => setState(() => _saturdayHour = i),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(':', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: kBrandCopper, height: 1.0)),
                          ),
                          Expanded(
                            child: _TimeWheel(
                              controller: _satMinuteController,
                              itemCount: 60,
                              initialValue: _saturdayMinute,
                              onSelectedItemChanged: (i) => setState(() => _saturdayMinute = i),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: kSpace3),

            // ── Repeat picker ───────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: '\u91cd\u590d'),
                  const SizedBox(height: kSpace3),
                  // Week type dropdown — drives RepeatPicker selection
                  _WeekTypeDropdown(
                    value: _repeatType,
                    onChanged: (type) {
                      setState(() {
                        _repeatType = type;
                        // Auto-set selectedDays based on dropdown choice
                        switch (type) {
                          case RepeatType.daily:
                            _selectedDays = [1, 2, 3, 4, 5, 6, 7];
                          case RepeatType.weekdays:
                            _selectedDays = [1, 2, 3, 4, 5];
                          case RepeatType.singleRest:
                            _selectedDays = [1, 2, 3, 4, 5, 6];
                          case RepeatType.doubleRest:
                            _selectedDays = [1, 2, 3, 4, 5];
                          case RepeatType.custom:
                            // Keep current selection for custom
                            break;
                          case RepeatType.once:
                          case RepeatType.weekends:
                            // These shouldn't appear in the dropdown,
                            // but handle gracefully
                            break;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: kSpace3),
                  RepeatPicker(
                    selectedDays: _selectedDays,
                    onChanged: (days) {
                      setState(() {
                        _selectedDays = days;
                        // Auto-infer repeatType from selected days
                        if (days.isEmpty) {
                          _repeatType = RepeatType.once;
                        } else if (days.length == 7 &&
                            days.every((d) => [1, 2, 3, 4, 5, 6, 7].contains(d))) {
                          _repeatType = RepeatType.daily;
                        } else if (days.length == 6 &&
                            days.every((d) => d >= 1 && d <= 6)) {
                          // Mon-Sat selected → singleRest (single-week gets 1 day off)
                          _repeatType = RepeatType.singleRest;
                        } else if (days.length == 5 &&
                            days.every((d) => d >= 1 && d <= 5)) {
                          // Mon-Fri → could be weekdays or doubleRest
                          // Prefer doubleRest as it's the more common alarm pattern
                          _repeatType = RepeatType.doubleRest;
                        } else if (days.length == 2 &&
                            days.contains(6) && days.contains(7)) {
                          _repeatType = RepeatType.weekends;
                        } else {
                          _repeatType = RepeatType.custom;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: kSpace3),

            // ── Label ───────────────────────────────────────
            _SectionCard(
              child: TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  hintText: '\u4f8b\u5982\uff1a\u8d77\u5e8a\u3001\u4e0a\u73ed',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: kBrandOutline, fontSize: 15),
                ),
                style: const TextStyle(fontSize: 15, color: kBrandTextPrimary),
              ),
            ),

            const SizedBox(height: kSpace3),

            // ── Ringtone ────────────────────────────────────
            _SectionCard(
              child: InkWell(
                onTap: _showRingtonePicker,
                borderRadius: BorderRadius.circular(kRadiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: kSpace1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionLabel(label: '铃声'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _ringtone == 'default' ? Icons.music_note_rounded : Icons.audio_file_rounded,
                            size: 16, color: kBrandCopper,
                          ),
                          const SizedBox(width: kSpace1),
                          Text(
                            _ringtoneTitle,
                            style: const TextStyle(fontSize: 14, color: kBrandTextSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: kSpace1),
                          const Icon(Icons.chevron_right, color: kBrandOutline, size: 18),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: kSpace6),
            // ── Closing task ─────────────────────────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: '关闭任务'),
                  const SizedBox(height: kSpace2),
                  Text(
                    '响铃时需要完成任务才能关闭闹钟',
                    style: TextStyle(fontSize: 12, color: kBrandTextSecondary),
                  ),
                  const SizedBox(height: kSpace3),
                  Row(
                    children: [
                      Expanded(
                        child: _TaskTypeChip(
                          label: '无',
                          icon: Icons.alarm_off_rounded,
                          selected: _taskType == AlarmTaskType.none,
                          onTap: () => setState(() => _taskType = AlarmTaskType.none),
                        ),
                      ),
                      const SizedBox(width: kSpace2),
                      Expanded(
                        child: _TaskTypeChip(
                          label: '算术题',
                          icon: Icons.calculate_rounded,
                          selected: _taskType == AlarmTaskType.math,
                          onTap: () => setState(() => _taskType = AlarmTaskType.math),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Save button ─────────────────────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBrandCopper,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: kBrandCopper.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMd)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('\u4fdd\u5b58', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: kSpace8),
          ],
        ),
      ),
    );
  }
}

// ── Roller wheel picker for hour / minute ─────────────────────────────────
//
// Uses a CupertinoPicker with custom builder that highlights the selected item
// with the brand copper colour and larger font, while dimming surrounding
// items for a polished, iOS-style roller feel.

class _TimeWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final int initialValue;
  final ValueChanged<int> onSelectedItemChanged;

  const _TimeWheel({
    required this.controller,
    required this.itemCount,
    required this.initialValue,
    required this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true, // Suppress overscroll glow
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 46,
        diameterRatio: 1.2,
        squeeze: 1.0,
        useMagnifier: true,
        magnification: 1.15,
        offAxisFraction: 0.0,
        looping: true,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: kBrandCopper.withValues(alpha: 0.08),
        ),
        onSelectedItemChanged: onSelectedItemChanged,
        children: List<Widget>.generate(itemCount, (index) {
          return _WheelItem(value: index, total: itemCount);
        }),
      ),
    );
  }
}

/// A single item inside the wheel.  It simply renders the padded number —
/// the CupertinoPicker's magnifier + selectionOverlay handle the visual
/// distinction between the selected row and its neighbours.
class _WheelItem extends StatelessWidget {
  final int value;
  final int total;

  const _WheelItem({required this.value, required this.total});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        value.toString().padLeft(2, '0'),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w400,
          color: kBrandTextPrimary,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

// ── Shared section card wrapping ───────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace5),
      decoration: BoxDecoration(
        color: kBrandSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBrandOutlineVariant, width: 0.5),
      ),
      child: child,
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: kBrandTextPrimary,
      ),
    );
  }
}

// ── Week type dropdown ─────────────────────────────────────────────────────

class _WeekTypeDropdown extends StatelessWidget {
  final RepeatType value;
  final ValueChanged<RepeatType> onChanged;

  const _WeekTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Map legacy types to display types for the dropdown
    // once/weekends are hidden from the menu — map them to closest visible type
    final displayValue = _toDisplayType(value);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 2),
      decoration: BoxDecoration(
        color: kBrandSurfaceAlt,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RepeatType>(
          value: displayValue,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: kBrandTextSecondary),
          style: const TextStyle(fontSize: 14, color: kBrandTextPrimary),
          items: const [
            DropdownMenuItem(value: RepeatType.daily, child: Text('每天 · 周一至周日')),
            DropdownMenuItem(value: RepeatType.weekdays, child: Text('工作日 · 周一至周五')),
            DropdownMenuItem(value: RepeatType.singleRest, child: Text('单双休 · 单周休一天')),
            DropdownMenuItem(value: RepeatType.doubleRest, child: Text('仅双休 · 周末全休')),
            DropdownMenuItem(value: RepeatType.custom, child: Text('自定义 · 手动选择')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  /// Map any RepeatType to a value that exists in the dropdown menu.
  /// Hidden types (once, weekends) are mapped to their closest visible equivalent.
  static RepeatType _toDisplayType(RepeatType type) {
    switch (type) {
      case RepeatType.once:
        return RepeatType.daily; // "once" (ring every day) maps to "每天"
      case RepeatType.weekends:
        return RepeatType.custom; // "weekends" maps to custom
      default:
        return type;
    }
  }
}
// ── Task type chip ─────────────────────────────────────────────
class _TaskTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TaskTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: kSpace3, horizontal: kSpace3),
        decoration: BoxDecoration(
          color: selected ? kBrandCopper.withValues(alpha: 0.12) : kBrandSurfaceAlt,
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(
            color: selected ? kBrandCopper : kBrandOutlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? kBrandCopper : kBrandTextSecondary),
            const SizedBox(width: kSpace1),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? kBrandCopper : kBrandTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
