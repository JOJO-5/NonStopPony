import 'package:flutter/material.dart';

const Color _kAccent = Color(0xFFE8936A);

class _Preset {
  final String label;
  final int seconds;
  const _Preset(this.label, this.seconds);
}

const _kPresets = [
  _Preset('1分钟', 60),
  _Preset('3分钟', 180),
  _Preset('5分钟', 300),
  _Preset('10分钟', 600),
  _Preset('15分钟', 900),
  _Preset('30分钟', 1800),
];

/// Horizontal scrollable row of preset duration chips.
class TimerPresets extends StatelessWidget {
  final ValueChanged<Duration> onSelected;

  const TimerPresets({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _kPresets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final preset = _kPresets[index];
          return _PresetChip(
            label: preset.label,
            onTap: () => onSelected(Duration(seconds: preset.seconds)),
          );
        },
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: _kAccent, width: 1.5),
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _kAccent,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}