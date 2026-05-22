import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import '../providers/schedule_provider.dart';
import '../models/week_schedule.dart';
import '../services/alarm_notification_service.dart';
import '../utils/date_utils.dart';
import '../app.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandWarmBg,
      appBar: AppBar(title: const Text('\u8bbe\u7f6e')),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          if (!provider.loaded) {
            provider.loadOverrides();
            return const Center(child: CircularProgressIndicator(color: kBrandCopper));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, kSpace12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeekTypeSection(context, provider),
                const SizedBox(height: kSpace3),
                _buildRingtoneSection(context),
                const SizedBox(height: kSpace3),
                _buildDiagnosticSection(context),
                const SizedBox(height: kSpace3),
                _buildMiuiSection(context),
                const SizedBox(height: kSpace3),
                _buildOtherSection(context),
                const SizedBox(height: kSpace3),
                _buildAboutSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Week type ─────────────────────────────────────────────────────────

  Widget _buildWeekTypeSection(BuildContext context, ScheduleProvider provider) {
    final now = DateTime.now();
    final weekOfMonth = ((now.day - 1) ~/ 7) + 1;
    final resolvedType = provider.resolveWeekType(now.year, now.month, weekOfMonth);
    final hasOverride = provider.overrides.cast<WeekSchedule?>().any(
      (o) => o!.year == now.year && o.month == now.month && o.weekOfMonth == weekOfMonth,
    );
    final autoType = autoWeekType(now);
    final autoLabel = autoType == WeekType.single ? '\u5355\u4f11\u5468' : '\u53cc\u4f11\u5468';
    final resolvedLabel = resolvedType == WeekType.single ? '\u5355\u4f11\u5468' : '\u53cc\u4f11\u5468';

    return _Card(
      title: '\u5f53\u524d\u5468\u8bbe\u7f6e',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${now.year}\u5e74\u7b2c${weekNumber(now)}\u5468',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kBrandTextPrimary),
              ),
              const SizedBox(width: kSpace2),
              Text(
                '\u81ea\u52a8: $autoLabel',
                style: const TextStyle(fontSize: 13, color: kBrandTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Row(
            children: [
              _TypeChip(
                label: '\u5355\u4f11\u5468',
                active: resolvedType == WeekType.single,
                activeColor: kBrandCopper,
                onTap: () => provider.setOverride(now.year, now.month, weekOfMonth, WeekType.single),
              ),
              const SizedBox(width: kSpace2),
              _TypeChip(
                label: '\u53cc\u4f11\u5468',
                active: resolvedType == WeekType.double,
                activeColor: kSemanticSuccess,
                onTap: () => provider.setOverride(now.year, now.month, weekOfMonth, WeekType.double),
              ),
              if (hasOverride) ...[
                const SizedBox(width: kSpace2),
                _TypeChip(
                  label: '\u6e05\u9664',
                  active: false,
                  activeColor: kBrandTextSecondary,
                  onTap: () => provider.removeOverride(now.year, now.month, weekOfMonth),
                ),
              ],
            ],
          ),
          const SizedBox(height: kSpace2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 5),
            decoration: BoxDecoration(
              color: (resolvedType == WeekType.single ? kBrandCopper : kSemanticSuccess).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(kRadiusSm),
            ),
            child: Text(
              '\u5f53\u524d: $resolvedLabel',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: resolvedType == WeekType.single ? kBrandCopper : kSemanticSuccess,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Ringtone ───────────────────────────────────────────────────────────

  Widget _buildRingtoneSection(BuildContext context) {
    return _Card(
      title: '\u94c3\u58f0\u8bbe\u7f6e',
      child: Column(
        children: [
          _RowTile(
            label: '\u9ed8\u8ba4\u94c3\u58f0',
            subtitle: '\u9ed8\u8ba4',
            trailing: const Icon(Icons.chevron_right, color: kBrandOutline, size: 18),
            onTap: () => _showRingtoneDialog(context),
          ),
          const _Divider(),
          _SwitchTile(label: '\u6e10\u5f3a', subtitle: '\u95f9\u949f\u54cd\u8d77\u65f6\u9010\u6e10\u589e\u5927\u97f3\u91cf', value: true, onChanged: (_) {}),
        ],
      ),
    );
  }

  void _showRingtoneDialog(BuildContext context) {
    const ringtones = ['\u9ed8\u8ba4', '\u65e5\u51fa', '\u6d77\u6d6a', '\u9e1f\u9e23', '\u94a2\u7434'];
    String selected = '\u9ed8\u8ba4';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
          title: const Text('\u9009\u62e9\u94c3\u58f0', style: TextStyle(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ringtones.map((name) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Text(name),
              value: name,
              groupValue: selected,
              activeColor: kBrandCopper,
              onChanged: (v) => setD(() => selected = v!),
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('\u53d6\u6d88', style: TextStyle(color: kBrandTextSecondary))),
            TextButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('\u786e\u5b9a', style: TextStyle(color: kBrandCopper))),
          ],
        ),
      ),
    );
  }

  // ── Notification diag ──────────────────────────────────────────────────

  Widget _buildDiagnosticSection(BuildContext context) {
    return _Card(
      title: '\u901a\u77e5\u8bca\u65ad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u5982\u679c\u95f9\u949f\u6ca1\u6709\u54cd\uff0c\u53ef\u80fd\u662f\u7cfb\u7edf\u901a\u77e5\u6743\u9650\u672a\u5f00\u542f', style: TextStyle(fontSize: 13, color: kBrandTextSecondary)),
          const SizedBox(height: kSpace3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testNotification,
              icon: const Icon(Icons.notifications_active_rounded, size: 18),
              label: const Text('\u6d4b\u8bd5\u901a\u77e5'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kBrandCopper,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _testNotification() {
    try {
      AlarmNotificationService().showAlarmNotification(
        alarmId: -1,
        title: '\u6d4b\u8bd5\u901a\u77e5',
        body: '\u5982\u679c\u80fd\u770b\u5230\u8fd9\u6761\u901a\u77e5\uff0c\u8bf4\u660e\u901a\u77e5\u6743\u9650\u548c\u94c3\u58f0\u90fd\u6b63\u5e38',
      );
    } catch (e) {
      debugPrint('Test notification error: $e');
    }
  }

  // ── MIUI diag ──────────────────────────────────────────────────────────

  Widget _buildMiuiSection(BuildContext context) {
    return _Card(
      title: 'Android \u95f9\u949f\u8bca\u65ad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\u5c0f\u7c73/HyperOS \u8bbe\u5907\u9700\u989d\u5916\u914d\u7f6e\u4ee5\u4e0b\u4e09\u9879', style: TextStyle(fontSize: 13, color: kBrandTextSecondary)),
          const SizedBox(height: kSpace3),
          _DiagStep(num: '1', title: '\u5173\u95ed\u7535\u6c60\u4f18\u5316', desc: '\u8bbe\u7f6e \u2192 \u5e94\u7528\u8bbe\u7f6e \u2192 \u6218\u9a6c\u95f9\u949f \u2192 \u7701\u7535\u7b56\u7565 \u2192 \u65e0\u9650\u5236'),
          const SizedBox(height: kSpace2),
          _DiagStep(num: '2', title: '\u5f00\u542f\u81ea\u542f\u52a8', desc: '\u8bbe\u7f6e \u2192 \u5e94\u7528\u8bbe\u7f6e \u2192 \u6218\u9a6c\u95f9\u949f \u2192 \u81ea\u542f\u52a8 \u2192 \u5f00\u542f'),
          const SizedBox(height: kSpace2),
          _DiagStep(num: '3', title: '\u95f9\u949f\u7cbe\u786e\u6743\u9650', desc: '\u8bbe\u7f6e \u2192 \u5e94\u7528\u8bbe\u7f6e \u2192 \u6218\u9a6c\u95f9\u949f \u2192 \u5176\u4ed6\u6743\u9650 \u2192 \u95f9\u949f\u6743\u9650 \u2192 \u5141\u8bb8'),
          const SizedBox(height: kSpace3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openAppSettings,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('\u6253\u5f00\u7cfb\u7edf\u5e94\u7528\u8bbe\u7f6e'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kBrandCopper,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
              ),
            ),
          ),
          const SizedBox(height: kSpace2),
          // Bug #4 fix: fullScreenIntent permission guide for Android 14+
          _RowTile(
            label: '锁屏闹钟提醒',
            subtitle: '需要开启权限才能在锁屏时显示全屏闹钟',
            trailing: const Icon(Icons.open_in_new_rounded, color: kBrandCopper, size: 18),
            onTap: _openFullScreenIntentSettings,
          ),
        ],
      ),
    );
  }

  void _openAppSettings() {
    try {
      const channel = MethodChannel('com.example.alarm_clock/settings');
      channel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('Failed to open app settings: $e');
    }
  }

  /// Bug #4 fix: Opens the USE_FULL_SCREEN_INTENT permission settings
  /// on Android 14+. Without this permission, the alarm cannot show
  /// a full-screen intent when the device is locked.
  void _openFullScreenIntentSettings() {
    try {
      const channel = MethodChannel('com.example.alarm_clock/settings');
      channel.invokeMethod('openFullScreenIntentSettings');
    } catch (e) {
      debugPrint('Failed to open full screen intent settings: $e');
    }
  }

  // ── Other ──────────────────────────────────────────────────────────────

  Widget _buildOtherSection(BuildContext context) {
    return _Card(
      title: '\u5176\u4ed6',
      child: Column(
        children: [
          _SwitchTile(label: '\u632f\u52a8', value: true, onChanged: (_) {}),
          const _Divider(),
          _SwitchTile(label: '\u591c\u95f4\u6a21\u5f0f (23:00-7:00 \u9759\u97f3)', subtitle: '\u591c\u95f4\u65f6\u6bb5\u81ea\u52a8\u9759\u97f3\u95f9\u949f', value: false, onChanged: (_) {}),
        ],
      ),
    );
  }

  // ── About ──────────────────────────────────────────────────────────────

  Widget _buildAboutSection() {
    return _Card(
      title: '\u5173\u4e8e',
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: kBrandCopper.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            child: const Icon(Icons.alarm_on_rounded, color: kBrandCopper, size: 26),
          ),
          const SizedBox(width: kSpace3),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('\u6218\u9a6c\u95f9\u949f', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBrandTextPrimary)),
                SizedBox(height: 2),
                Text('v1.0.0 \u2014 \u667a\u80fd\u5355\u53cc\u4f11\u95f9\u949f', style: TextStyle(fontSize: 12, color: kBrandTextSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace5),
      decoration: BoxDecoration(
        color: kBrandSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBrandOutlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kBrandTextSecondary, letterSpacing: 0.5)),
          const SizedBox(height: kSpace3),
          child,
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _RowTile({required this.label, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: kSpace1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, color: kBrandTextPrimary)),
                  if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: kBrandTextSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchTile({required this.label, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 14, color: kBrandTextPrimary)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(fontSize: 12, color: kBrandTextSecondary)),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kBrandCopper,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: kSpace1),
    child: Divider(height: 1, color: kBrandOutlineVariant),
  );
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.active, required this.activeColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : activeColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(kRadiusSm),
          border: Border.all(color: active ? activeColor : activeColor.withValues(alpha: 0.25), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? Colors.white : activeColor),
        ),
      ),
    );
  }
}

class _DiagStep extends StatelessWidget {
  final String num;
  final String title;
  final String desc;
  const _DiagStep({required this.num, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: kBrandCopper.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(child: Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kBrandCopper))),
        ),
        const SizedBox(width: kSpace2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kBrandTextPrimary)),
              const SizedBox(height: 1),
              Text(desc, style: const TextStyle(fontSize: 11, color: kBrandTextSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
