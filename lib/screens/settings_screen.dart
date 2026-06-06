import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../models/week_schedule.dart';
import '../services/alarm_notification_service.dart';
import '../services/holiday_service.dart';
import '../services/settings_preferences_service.dart';
import '../utils/date_utils.dart';
import '../screens/ringtone_picker_screen.dart';
import '../screens/about_screen.dart';
import '../app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _ringtoneUri = SettingsPreferencesService.defaultRingtoneUri;
  String _ringtoneTitle = SettingsPreferencesService.defaultRingtoneTitle;
  bool _ringtoneLoaded = false;

  // Switch states
  bool _volumeRamp = true;
  bool _vibration = true;
  bool _nightMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ScheduleProvider>();
      if (!provider.loaded) {
        provider.loadOverrides();
      }
      _loadRingtonePref();
    });
  }

  Future<void> _loadRingtonePref() async {
    final uri = await SettingsPreferencesService.getRingtoneUri();
    final title = await SettingsPreferencesService.getRingtoneTitle();
    if (mounted) {
      setState(() {
        _ringtoneUri = uri;
        _ringtoneTitle = title;
        _ringtoneLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandWarmBg,
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          if (!provider.loaded) {
            return const Center(child: CircularProgressIndicator(color: kBrandCopper));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, kSpace12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeekTypeSection(context, provider),
                const SizedBox(height: kSpace3),
                _buildHolidaySection(context),
                const SizedBox(height: kSpace3),
                _buildRingtoneSection(context),
                const SizedBox(height: kSpace3),
                _buildDiagnosticSection(context),
                const SizedBox(height: kSpace3),
                _buildPermissionSection(context),
                const SizedBox(height: kSpace3),
                _buildMiuiSection(context),
                const SizedBox(height: kSpace3),
                _buildOtherSection(context),
                const SizedBox(height: kSpace3),
                _buildAboutSection(context),
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
    final autoLabel = autoType == WeekType.single ? '单休周' : '双休周';
    final resolvedLabel = resolvedType == WeekType.single ? '单休周' : '双休周';

    return _Card(
      title: '当前周设置',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${now.year}年第${weekNumber(now)}周',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kBrandTextPrimary),
              ),
              const SizedBox(width: kSpace2),
              Text(
                '自动: $autoLabel',
                style: const TextStyle(fontSize: 13, color: kBrandTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Row(
            children: [
              _TypeChip(
                label: '单休周',
                active: resolvedType == WeekType.single,
                activeColor: kBrandCopper,
                onTap: () => provider.setOverride(now.year, now.month, weekOfMonth, WeekType.single),
              ),
              const SizedBox(width: kSpace2),
              _TypeChip(
                label: '双休周',
                active: resolvedType == WeekType.double,
                activeColor: kSemanticSuccess,
                onTap: () => provider.setOverride(now.year, now.month, weekOfMonth, WeekType.double),
              ),
              if (hasOverride) ...[
                const SizedBox(width: kSpace2),
                _TypeChip(
                  label: '清除',
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
              '当前: $resolvedLabel',
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

  // ── Holiday sync ─────────────────────────────────────────────────────

  Widget _buildHolidaySection(BuildContext context) {
    return _Card(
      title: '法定节假日',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('自动同步国家法定节假日和调休安排', style: TextStyle(fontSize: 13, color: kBrandTextSecondary)),
          const SizedBox(height: 2),
          const Text('假期日闹钟不响，补班日闹钟照常响', style: TextStyle(fontSize: 13, color: kBrandCopper, fontWeight: FontWeight.w500)),
          const SizedBox(height: kSpace3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  final now = DateTime.now();
                  final cnt1 = await HolidayService.fetchAndCacheYear(now.year);
                  final cnt2 = await HolidayService.fetchAndCacheYear(now.year + 1);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('同步完成：${now.year}年 $cnt1 条，${now.year + 1}年 $cnt2 条'),
                        backgroundColor: kSemanticSuccess,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('同步失败：$e'),
                        backgroundColor: kSemanticError,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.cloud_download_rounded, size: 18),
              label: const Text('立即同步节假日数据'),
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

  // ── Ringtone ──────────────────────────────────────────────────────────────────

  Widget _buildRingtoneSection(BuildContext context) {
    final subtitle = !_ringtoneLoaded
        ? '加载中…'
        : _ringtoneUri == SettingsPreferencesService.defaultRingtoneUri
            ? _ringtoneTitle
            : _ringtoneTitle.length > 12
                ? '${_ringtoneTitle.substring(0, 12)}…'
                : _ringtoneTitle;

    return _Card(
      title: '铃声设置',
      child: Column(
        children: [
          _RowTile(
            label: '默认铃声',
            subtitle: subtitle,
            trailing: const Icon(Icons.chevron_right, color: kBrandOutline, size: 18),
            onTap: () async {
              final result = await Navigator.push<RingtoneSelection>(
                context,
                PageRouteBuilder(
                  opaque: true,
                  pageBuilder: (_, _, _) => RingtonePickerScreen(
                    currentRingtone: _ringtoneUri,
                    currentRingtoneTitle: _ringtoneTitle,
                  ),
                  transitionsBuilder: (_, animation, _, child) =>
                      FadeTransition(opacity: animation, child: child),
                  transitionDuration: const Duration(milliseconds: 250),
                ),
              );
              if (result != null && mounted) {
                await SettingsPreferencesService.setRingtone(result.uri, result.title);
                setState(() {
                  _ringtoneUri = result.uri;
                  _ringtoneTitle = result.title;
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('默认铃声已设为「${result.title}」'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      backgroundColor: kSemanticSuccess,
                    ),
                  );
                }
              }
            },
          ),
          const _Divider(),
          _SwitchTile(label: '渐强', subtitle: '闹钟响起时逐渐增大音量', value: _volumeRamp, onChanged: (v) => setState(() => _volumeRamp = v)),
        ],
      ),
    );
  }

  // ── Notification diag ──────────────────────────────────────────────────

  Widget _buildDiagnosticSection(BuildContext context) {
    return _Card(
      title: '通知诊断',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('如果闹钟没有响，可能是系统通知权限未开启', style: TextStyle(fontSize: 13, color: kBrandTextSecondary)),
          const SizedBox(height: kSpace3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testNotification,
              icon: const Icon(Icons.notifications_active_rounded, size: 18),
              label: const Text('测试通知'),
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
        title: '测试通知',
        body: '如果能看到这条通知，说明通知权限和铃声都正常',
      );
    } catch (e) {
      debugPrint('Test notification error: $e');
    }
  }

  // ── Permission status ────────────────────────────────────────────────

  Widget _buildPermissionSection(BuildContext context) {
    return _Card(
      title: '权限检测',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('如果闹钟不响，请确保以下权限已开启', style: TextStyle(fontSize: 13, color: kBrandTextSecondary)),
          const SizedBox(height: kSpace3),
          _PermissionButton(
            icon: Icons.notifications_rounded,
            label: '通知权限',
            desc: '接收闹钟响铃通知',
            onTap: () async {
              final plugin = AlarmNotificationService();
              await plugin.requestAndroidPermissions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已请求通知权限，请查看系统弹窗'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: kSpace2),
          _PermissionButton(
            icon: Icons.alarm_rounded,
            label: '精确闹钟权限',
            desc: '保证闹钟在精确时间触发',
            onTap: () async {
              final plugin = AlarmNotificationService();
              await plugin.requestAndroidPermissions();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已请求精确闹钟权限，请查看系统弹窗'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: kSpace2),
          _PermissionButton(
            icon: Icons.battery_charging_full,
            label: '忽略电池优化',
            desc: '避免系统在后台杀死闹钟进程',
            onTap: () async {
              final plugin = AlarmNotificationService();
              await plugin.requestIgnoreBatteryOptimizations();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已请求电池优化白名单'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ── MIUI diag ──────────────────────────────────────────────────────────

  Widget _buildMiuiSection(BuildContext context) {
    return _Card(
      title: 'Android 闹钟诊断',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('小米/HyperOS 设备需额外配置以下三项', style: TextStyle(fontSize: 13, color: kBrandTextSecondary)),
          const SizedBox(height: kSpace3),
          _DiagStep(num: '1', title: '关闭电池优化', desc: '设置 → 应用设置 → 战马闹钟 → 省电策略 → 无限制'),
          const SizedBox(height: kSpace2),
          _DiagStep(num: '2', title: '开启自启动', desc: '设置 → 应用设置 → 战马闹钟 → 自启动 → 开启'),
          const SizedBox(height: kSpace2),
          _DiagStep(num: '3', title: '闹钟精确权限', desc: '设置 → 应用设置 → 战马闹钟 → 其他权限 → 闹钟权限 → 允许'),
          const SizedBox(height: kSpace3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openAppSettings,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('打开系统应用设置'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kBrandCopper,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
              ),
            ),
          ),
          const SizedBox(height: kSpace2),
          _PermissionButton(
            icon: Icons.open_in_new_rounded,
            label: '后台弹出界面',
            desc: '应用详情 → 其他权限 → 开启「后台弹出界面」',
            onTap: _openMiuiPermissionEditor,
          ),
          const SizedBox(height: kSpace2),
          _PermissionButton(
            icon: Icons.lock_outline_rounded,
            label: '锁屏显示',
            desc: '应用详情 → 其他权限 → 开启「锁屏显示」',
            onTap: _openMiuiPermissionEditor,
          ),
          const SizedBox(height: kSpace2),
          _RowTile(
            label: '锁屏全屏显示',
            subtitle: 'Android 14+ 全屏通知权限，开启后闹钟可在锁屏弹出全屏界面',
            trailing: const Icon(Icons.open_in_new_rounded, color: kBrandCopper, size: 18),
            onTap: _openFullScreenIntentSettings,
          ),
          const SizedBox(height: kSpace3),
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

  void _openFullScreenIntentSettings() {
    try {
      const channel = MethodChannel('com.example.alarm_clock/settings');
      channel.invokeMethod('openFullScreenIntentSettings');
    } catch (e) {
      debugPrint('Failed to open full screen intent settings: $e');
    }
  }

  void _openMiuiPermissionEditor() {
    try {
      const channel = MethodChannel('com.example.alarm_clock/settings');
      channel.invokeMethod('openMiuiPermissionEditor');
    } catch (e) {
      debugPrint('Failed to open MIUI permission editor: $e');
    }
  }

  // ── Other ──────────────────────────────────────────────────────────────

  Widget _buildOtherSection(BuildContext context) {
    return _Card(
      title: '其他',
      child: Column(
        children: [
          _SwitchTile(label: '震动', value: _vibration, onChanged: (v) => setState(() => _vibration = v)),
          const _Divider(),
          _SwitchTile(label: '夜间模式 (23:00-7:00 静音)', subtitle: '夜间时段自动静音闹钟', value: _nightMode, onChanged: (v) => setState(() => _nightMode = v)),
        ],
      ),
    );
  }

  // ── About ──────────────────────────────────────────────────────────────

  Widget _buildAboutSection(BuildContext context) {
    return _Card(
      title: '关于',
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              opaque: true,
              pageBuilder: (_, _, _) => const AboutScreen(),
              transitionsBuilder: (_, animation, _, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 250),
            ),
          );
        },
        borderRadius: BorderRadius.circular(kRadiusMd),
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
                  Text('战马闹钟', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kBrandTextPrimary)),
                  SizedBox(height: 2),
                  Text('v1.0.0', style: TextStyle(fontSize: 12, color: kBrandTextSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kBrandOutline, size: 18),
          ],
        ),
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
                  if (subtitle case final subtitle?) Text(subtitle, style: const TextStyle(fontSize: 12, color: kBrandTextSecondary)),
                ],
              ),
            ),
            if (trailing case final trailing?) trailing,
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
              if (subtitle case final subtitle?) Text(subtitle, style: const TextStyle(fontSize: 12, color: kBrandTextSecondary)),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.85,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: kBrandCopper,
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

/// Permission action button used in [SettingsScreen._buildPermissionSection].
class _PermissionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;

  const _PermissionButton({
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrandTextPrimary,
        side: const BorderSide(color: kBrandOutlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusSm)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kBrandCopper),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kBrandTextPrimary)),
                Text(desc,
                    style: const TextStyle(fontSize: 11, color: kBrandTextSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: kBrandOutline),
        ],
      ),
    );
  }
}
