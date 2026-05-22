import 'package:flutter/material.dart';

/// Day-of-week labels in Chinese, indexed 1–7 (Mon–Sun).
const Map<int, String> _kDayLabels = {
  1: '一',
  2: '二',
  3: '三',
  4: '四',
  5: '五',
  6: '六',
  7: '日',
};

const List<int> _kAllDays = [1, 2, 3, 4, 5, 6, 7];
const List<int> _kWorkdays = [1, 2, 3, 4, 5];
const List<int> _kWeekend = [6, 7];

const Color _kSelectedBg = Color(0xFFE8936A);
const Color _kUnselectedBg = Color(0xFFF0EDE8);
const Color _kSelectedText = Colors.white;
const Color _kUnselectedText = Color(0xFF4A4A4A);

class RepeatPicker extends StatefulWidget {
  final List<int> selectedDays;
  final ValueChanged<List<int>> onChanged;

  const RepeatPicker({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  @override
  State<RepeatPicker> createState() => _RepeatPickerState();
}

class _RepeatPickerState extends State<RepeatPicker> {
  bool _isSelected(int day) => widget.selectedDays.contains(day);

  void _toggle(int day) {
    final days = List<int>.from(widget.selectedDays);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    days.sort();
    widget.onChanged(days);
  }

  void _setDays(List<int> days) {
    widget.onChanged(List<int>.from(days));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick-select row
        Row(
          children: [
            _QuickSelectChip(
              label: '每天',
              isActive: _listEquals(widget.selectedDays, _kAllDays),
              onTap: () => _setDays(_kAllDays),
            ),
            const SizedBox(width: 8),
            _QuickSelectChip(
              label: '工作日',
              isActive: _listEquals(widget.selectedDays, _kWorkdays),
              onTap: () => _setDays(_kWorkdays),
            ),
            const SizedBox(width: 8),
            _QuickSelectChip(
              label: '周末',
              isActive: _listEquals(widget.selectedDays, _kWeekend),
              onTap: () => _setDays(_kWeekend),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Day circles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _kAllDays.map((day) {
            final selected = _isSelected(day);
            return GestureDetector(
              onTap: () => _toggle(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? _kSelectedBg : _kUnselectedBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _kDayLabels[day]!,
                  style: TextStyle(
                    color: selected ? _kSelectedText : _kUnselectedText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _QuickSelectChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickSelectChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? _kSelectedBg : _kUnselectedBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? _kSelectedText : _kUnselectedText,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}