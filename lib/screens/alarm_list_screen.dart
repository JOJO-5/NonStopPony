import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/alarm_provider.dart';
import '../models/alarm_info.dart';
import '../services/alarm_notification_service.dart';
import '../services/holiday_service.dart';
import '../widgets/alarm_tile.dart';
import '../providers/schedule_provider.dart';
import '../models/week_schedule.dart';
import '../app.dart';
import 'add_edit_alarm_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen>
    with WidgetsBindingObserver {
  HolidayInfo? _todayHoliday;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlarmProvider>().loadAlarms();
      _loadTodayHoliday();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlarmNotificationService().requestAndroidPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// An alarm can be dismissed while the app is backgrounded (native ringing
  /// notification), which changes the database without touching the in-memory
  /// list. Reload on resume so the switches always match the stored state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AlarmProvider>().loadAlarms();
      _loadTodayHoliday();
    }
  }

  Future<void> _loadTodayHoliday() async {
    final info = await HolidayService.getHolidayInfo(DateTime.now());
    if (mounted && info != null) {
      setState(() {
        _todayHoliday = info;
      });
    }
  }

  Future<void> _navigateToAdd() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddEditAlarmScreen()),
    );
    if (result == true && mounted) {
      await context.read<AlarmProvider>().loadAlarms();
    }
  }

  Future<void> _navigateToEdit(AlarmInfo alarm) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddEditAlarmScreen(alarm: alarm)),
    );
    if (result == true && mounted) {
      await context.read<AlarmProvider>().loadAlarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    const weekDays = ['\u4e00', '\u4e8c', '\u4e09', '\u56db', '\u4e94', '\u516d', '\u65e5'];
    final dateStr = '${now.month}\u6708${now.day}\u65e5 \u661f\u671f${weekDays[now.weekday - 1]}';
    final isSingleWeek =
        context.watch<ScheduleProvider>().resolveWeekTypeByDate(now) == WeekType.single;

    return Scaffold(
      backgroundColor: kBrandWarmBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Sunrise hero ────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, 0),
              padding: const EdgeInsets.fromLTRB(kSpace5, kSpace5, kSpace5, kSpace4),
              decoration: BoxDecoration(
                gradient: kSunriseGradient,
                borderRadius: BorderRadius.circular(kRadiusXl),
                boxShadow: kShadowSoft,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontSize: 13,
                                color: kBrandCopperDeep,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '\u6218\u9a6c\u95f9\u949f',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w700,
                                color: kBrandTextPrimary,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const _BrandBadge(),
                    ],
                  ),
                  const SizedBox(height: kSpace4),
                  Row(
                    children: [
                      _HeroPill(
                        icon: isSingleWeek ? Icons.wb_twilight_rounded : Icons.weekend_rounded,
                        text: isSingleWeek ? '本周单休' : '本周双休',
                        color: isSingleWeek ? kBrandCopperDeep : kSemanticSuccess,
                      ),
                      if (_todayHoliday != null) ...[
                        const SizedBox(width: kSpace2),
                        _HeroPill(
                          icon: _todayHoliday!.isHoliday
                              ? Icons.beach_access_rounded
                              : Icons.work_rounded,
                          text: _todayHoliday!.name ??
                              (_todayHoliday!.isHoliday ? '假期' : '补班'),
                          color: _todayHoliday!.isHoliday ? kSemanticSuccess : kBrandCopperDeep,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: kSpace5),

            // ── Alarm List ──────────────────────────────────────
            Expanded(
              child: Consumer<AlarmProvider>(
                builder: (context, provider, _) {
                  if (!provider.loaded) {
                    return const Center(
                      child: CircularProgressIndicator(color: kBrandCopper),
                    );
                  }

                  final alarms = provider.alarms;

                  if (alarms.isEmpty) {
                    return _EmptyHero(onAdd: _navigateToAdd);
                  }

                  // Group: active first, then inactive
                  final active = alarms.where((a) => a.isEnabled).toList();
                  final inactive = alarms.where((a) => !a.isEnabled).toList();

                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: kSpace12),
                    itemCount: alarms.length + (inactive.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Section header before inactive group
                      if (inactive.isNotEmpty && index == active.length) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(kSpace6, kSpace4, kSpace6, kSpace2),
                          child: Text(
                            '\u5df2\u505c\u7528',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }

                      final alarm = index < active.length
                          ? active[index]
                          : inactive[index - active.length - 1];

                      return Dismissible(
                        key: ValueKey(alarm.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLg)),
                              title: const Text('\u5220\u9664\u95f9\u949f'),
                              content: Text(
                                '\u786e\u5b9a\u8981\u5220\u9664 ${alarm.hour}:${alarm.minute.toString().padLeft(2, '0')} \u7684\u95f9\u949f\u5417\uff1f',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('\u53d6\u6d88', style: TextStyle(color: kBrandTextSecondary)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('\u5220\u9664', style: TextStyle(color: kSemanticError)),
                                ),
                              ],
                            ),
                          );
                          return confirm ?? false;
                        },
                        onDismissed: (_) {
                          context.read<AlarmProvider>().removeAlarm(alarm.id!);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: kSpace6),
                          margin: const EdgeInsets.symmetric(horizontal: kSpace5, vertical: 5),
                          decoration: BoxDecoration(
                            color: kSemanticError,
                            borderRadius: BorderRadius.circular(kRadiusLg),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
                        ),
                        child: AlarmTile(
                          alarm: alarm,
                          onToggle: () => context.read<AlarmProvider>().toggleAlarm(alarm.id!),
                          onTap: () => _navigateToEdit(alarm),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // ── Primary CTA at bottom ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace5, 0, kSpace5, kSpace3),
              child: _GradientButton(
                label: '\u6dfb\u52a0\u95f9\u949f',
                icon: Icons.add_rounded,
                onTap: _navigateToAdd,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Brand badge (hero, top-right) ──────────────────────────────────────────

class _BrandBadge extends StatelessWidget {
  const _BrandBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(kRadiusMd),
        boxShadow: [
          BoxShadow(
            color: kBrandCopper.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Icon(Icons.alarm_on_rounded, color: kBrandCopperDeep, size: 24),
    );
  }
}

// ── Hero pill (week type / holiday) ────────────────────────────────────────

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _HeroPill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Gradient primary button ────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool expanded;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: expanded ? double.infinity : null,
        height: 52,
        padding: expanded ? null : const EdgeInsets.symmetric(horizontal: kSpace6),
        decoration: BoxDecoration(
          gradient: kCopperGradient,
          borderRadius: BorderRadius.circular(kRadiusMd),
          boxShadow: kShadowGlow,
        ),
        child: Row(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: kSpace2),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyHero extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHero({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: const BoxDecoration(
                gradient: kSunriseGradient,
                shape: BoxShape.circle,
                boxShadow: kShadowRaised,
              ),
              child: const Icon(Icons.alarm_add_rounded, color: Colors.white, size: 56),
            ),
            const SizedBox(height: kSpace6),
            const Text(
              '\u8fd8\u6ca1\u6709\u95f9\u949f',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: kBrandTextPrimary,
              ),
            ),
            const SizedBox(height: kSpace2),
            const Text(
              '\u6dfb\u52a0\u7b2c\u4e00\u4e2a\u95f9\u949f\uff0c\u8ba9\u6218\u9a6c\u53eb\u4f60\u8d77\u5e8a',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: kBrandTextSecondary),
            ),
            const SizedBox(height: kSpace6),
            _GradientButton(
              label: '\u6dfb\u52a0\u95f9\u949f',
              icon: Icons.add_rounded,
              onTap: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
