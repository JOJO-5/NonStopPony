import 'package:flutter/material.dart';
import '../models/alarm_info.dart';
import '../models/week_schedule.dart';
import '../utils/date_utils.dart';
import '../app.dart';

/// A tile displaying a single alarm with large time, repeat info, and toggle.
class AlarmTile extends StatelessWidget {
  final AlarmInfo alarm;
  final VoidCallback onToggle;
  final VoidCallback onTap;

  const AlarmTile({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = alarm.isEnabled;
    final opacity = isActive ? 1.0 : 0.45;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kSpace5, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(
          color: isActive
              ? colorScheme.outlineVariant
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: kBrandBrown.withValues(alpha: isActive ? 0.04 : 0.02),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(kRadiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusLg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpace5, kSpace4, kSpace3, kSpace4),
            child: Opacity(
              opacity: opacity,
              child: Row(
                children: [
                  // ── Left: time + meta ────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TimeDisplay(alarm: alarm),
                        const SizedBox(height: 6),
                        _MetaRow(alarm: alarm),
                      ],
                    ),
                  ),

                  // ── Right: switch ─────────────────────────────
                  Transform.scale(
                    scale: 0.9,
                    child: Switch(
                      value: isActive,
                      onChanged: (_) => onToggle(),
                      activeColor: kBrandCopper,
                      activeTrackColor: kBrandCopper.withValues(alpha: 0.3),
                      inactiveThumbColor: colorScheme.outline,
                      inactiveTrackColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Large time display: "7:30"
class _TimeDisplay extends StatelessWidget {
  final AlarmInfo alarm;
  const _TimeDisplay({required this.alarm});

  @override
  Widget build(BuildContext context) {
    final h = alarm.hour.toString().padLeft(2, '0');
    final m = alarm.minute.toString().padLeft(2, '0');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$h:$m',
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w300,
            color: kBrandTextPrimary,
            height: 1.1,
            letterSpacing: -1,
          ),
        ),
        if (alarm.label != null && alarm.label!.isNotEmpty) ...[
          const SizedBox(width: kSpace3),
          Flexible(
            child: Text(
              alarm.label!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: kBrandTextSecondary,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Repeat description + week type badge row
class _MetaRow extends StatelessWidget {
  final AlarmInfo alarm;
  const _MetaRow({required this.alarm});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    final repeatText = _repeatLabel(alarm);
    if (repeatText != null) {
      badges.add(_Badge(text: repeatText, outlined: true));
    }

    final weekBadge = _weekBadge(alarm);
    if (weekBadge != null) {
      badges.add(weekBadge);
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 6, runSpacing: 4, children: badges);
  }

  String? _repeatLabel(AlarmInfo a) {
    switch (a.repeatType) {
      case RepeatType.once:
        return '\u4ec5\u4e00\u6b21';
      case RepeatType.daily:
        return '\u6bcf\u5929';
      case RepeatType.weekdays:
        return '\u5de5\u4f5c\u65e5';
      case RepeatType.weekends:
        return '\u5468\u672b';
      case RepeatType.singleRest:
        return '\u5355\u4f11';
      case RepeatType.doubleRest:
        return '\u53cc\u4f11';
      case RepeatType.custom:
        if (a.weekdays.isEmpty) return '\u4ec5\u4e00\u6b21';
        final sorted = List<int>.from(a.weekdays)..sort();
        return sorted.map((d) {
          const m = {1: '\u4e00', 2: '\u4e8c', 3: '\u4e09', 4: '\u56db', 5: '\u4e94', 6: '\u516d', 7: '\u65e5'};
          return m[d] ?? '';
        }).join(' ');
    }
  }

  Widget? _weekBadge(AlarmInfo a) {
    if (a.repeatType != RepeatType.singleRest && a.repeatType != RepeatType.doubleRest) return null;
    final now = DateTime.now();
    final wt = resolveWeekType(now, []);
    final isSingle = wt == WeekType.single;

    if (a.repeatType == RepeatType.singleRest) {
      return _Badge(
        text: isSingle ? '\u672c\u5468\u5355\u4f11' : '\u672c\u5468\u53cc\u4f11',
        color: isSingle ? kBrandCopper : kSemanticSuccess,
      );
    }
    return const _Badge(text: '\u5468\u672b\u5173\u95ed', outlined: true);
  }
}

/// A small tag badge
class _Badge extends StatelessWidget {
  final String text;
  final Color? color;
  final bool outlined;

  const _Badge({required this.text, this.color, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? kBrandTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: outlined ? null : c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: outlined ? Border.all(color: c.withValues(alpha: 0.35), width: 0.5) : null,
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c),
      ),
    );
  }
}
