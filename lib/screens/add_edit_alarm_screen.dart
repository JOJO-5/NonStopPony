import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alarm_info.dart';
import '../providers/alarm_provider.dart';
import '../widgets/repeat_picker.dart';
import '../app.dart';

const _kRingtones = ['\u9ed8\u8ba4', '\u65e5\u51fa', '\u6d77\u6d6a', '\u9e1f\u9e23'];

class AddEditAlarmScreen extends StatefulWidget {
  final AlarmInfo? alarm;
  const AddEditAlarmScreen({super.key, this.alarm});

  @override
  State<AddEditAlarmScreen> createState() => _AddEditAlarmScreenState();
}

class _AddEditAlarmScreenState extends State<AddEditAlarmScreen> {
  late int _hour, _minute;
  late List<int> _selectedDays;
  late RepeatType _repeatType;
  late TextEditingController _labelController;
  late String _ringtone;
  bool _saving = false;

  bool get _isEditing => widget.alarm != null;

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    _hour = a?.hour ?? 7;
    _minute = a?.minute ?? 0;
    _selectedDays = a != null ? List<int>.from(a.weekdays) : [];
    _repeatType = a?.repeatType ?? RepeatType.once;
    _labelController = TextEditingController(text: a?.label ?? '');
    _ringtone = a?.ringtone ?? '\u9ed8\u8ba4';
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _incrementHour() => setState(() => _hour = (_hour + 1) % 24);
  void _decrementHour() => setState(() => _hour = (_hour - 1 + 24) % 24);
  void _incrementMinute() => setState(() => _minute = (_minute + 1) % 60);
  void _decrementMinute() => setState(() => _minute = (_minute - 1 + 60) % 60);

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

  void _showRingtonePicker() {
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('\u9009\u62e9\u94c3\u58f0'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
        children: _kRingtones.map((name) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() => _ringtone = name);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                Icon(
                  _ringtone == name ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: _ringtone == name ? kBrandCopper : kBrandTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: kSpace3),
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: _ringtone == name ? FontWeight.w600 : FontWeight.normal,
                    color: _ringtone == name ? kBrandCopper : kBrandTextPrimary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            // ── Inline time setter ──────────────────────────
            _SectionCard(
              child: Column(
                children: [
                  const Text(
                    '\u65f6\u95f4',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBrandTextSecondary),
                  ),
                  const SizedBox(height: kSpace4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Hour column
                      _TimeColumn(
                        value: _hour.toString().padLeft(2, '0'),
                        onUp: _incrementHour,
                        onDown: _decrementHour,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: kSpace2),
                        child: Text(
                          ':',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w200,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      // Minute column
                      _TimeColumn(
                        value: _minute.toString().padLeft(2, '0'),
                        onUp: _incrementMinute,
                        onDown: _decrementMinute,
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace2),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
                  RepeatPicker(
                    selectedDays: _selectedDays,
                    onChanged: (days) => setState(() => _selectedDays = days),
                  ),
                ],
              ),
            ),

            const SizedBox(height: kSpace3),

            // ── Week type (single/double rest) ──────────────
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: '\u5355\u53cc\u4f11'),
                  const SizedBox(height: 4),
                  const Text(
                    '\u8bbe\u7f6e\u95f9\u949f\u4ec5\u5728\u5355\u5468\u6216\u53cc\u5468\u751f\u6548',
                    style: TextStyle(fontSize: 12, color: kBrandTextSecondary),
                  ),
                  const SizedBox(height: kSpace3),
                  _WeekTypeDropdown(
                    value: _repeatType,
                    onChanged: (type) => setState(() => _repeatType = type),
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
                      const _SectionLabel(label: '\u94c3\u58f0'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_ringtone, style: const TextStyle(fontSize: 14, color: kBrandTextSecondary)),
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

// ── Inline time column (hour/minute with +/- buttons) ──────────────────────

class _TimeColumn extends StatelessWidget {
  final String value;
  final VoidCallback onUp;
  final VoidCallback onDown;

  const _TimeColumn({required this.value, required this.onUp, required this.onDown});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: Icons.keyboard_arrow_up_rounded,
          onTap: onUp,
          color: colorScheme,
        ),
        Container(
          width: 100,
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(kRadiusMd),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w200,
                color: colorScheme.onSurface,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        _ArrowButton(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: onDown,
          color: colorScheme,
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme color;

  const _ArrowButton({required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 36,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 28, color: color.onSurfaceVariant),
        splashRadius: 18,
        padding: EdgeInsets.zero,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 2),
      decoration: BoxDecoration(
        color: kBrandSurfaceAlt,
        borderRadius: BorderRadius.circular(kRadiusSm),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RepeatType>(
          value: value,
          isDense: true,
          isExpanded: true,
          icon: const Icon(Icons.expand_more_rounded, color: kBrandTextSecondary),
          style: const TextStyle(fontSize: 14, color: kBrandTextPrimary),
          items: const [
            DropdownMenuItem(value: RepeatType.once, child: Text('\u5168\u90e8')),
            DropdownMenuItem(value: RepeatType.singleRest, child: Text('\u4ec5\u5355\u5468')),
            DropdownMenuItem(value: RepeatType.doubleRest, child: Text('\u4ec5\u53cc\u5468')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
