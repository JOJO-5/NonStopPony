import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/alarm_provider.dart';
import '../models/alarm_info.dart';
import '../services/alarm_notification_service.dart';
import '../services/holiday_service.dart';
import '../widgets/alarm_tile.dart';
import '../app.dart';
import 'add_edit_alarm_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  HolidayInfo? _todayHoliday;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlarmProvider>().loadAlarms();
      _loadTodayHoliday();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlarmNotificationService().requestAndroidPermissions();
    });
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

    return Scaffold(
      backgroundColor: kBrandWarmBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace6, kSpace4, kSpace6, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_todayHoliday != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: _todayHoliday!.isHoliday
                                    ? kSemanticSuccess.withValues(alpha: 0.15)
                                    : kBrandCopper.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _todayHoliday!.isHoliday
                                    ? _todayHoliday!.name ?? '假期'
                                    : _todayHoliday!.name ?? '补班',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _todayHoliday!.isHoliday ? kSemanticSuccess : kBrandCopper,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\u6218\u9a6c\u95f9\u949f',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  _BrandBadge(colorScheme: colorScheme),
                ],
              ),
            ),

            const SizedBox(height: kSpace6),

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

            // ── FAB bar at bottom ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace5, 0, kSpace5, kSpace3),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _navigateToAdd,
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text('\u6dfb\u52a0\u95f9\u949f'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandCopper,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Brand badge (top-right) ────────────────────────────────────────────────

class _BrandBadge extends StatelessWidget {
  final ColorScheme colorScheme;
  const _BrandBadge({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: const Icon(Icons.alarm_on_rounded, color: kBrandCopper, size: 22),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyHero extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHero({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(kRadiusXl),
              ),
              child: const Icon(Icons.alarm_add_rounded, color: kBrandCopper, size: 44),
            ),
            const SizedBox(height: kSpace6),
            Text(
              '\u8fd8\u6ca1\u6709\u95f9\u949f',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: kSpace2),
            Text(
              '\u6dfb\u52a0\u7b2c\u4e00\u4e2a\u95f9\u949f\uff0c\u8ba9\u6218\u9a6c\u53eb\u4f60\u8d77\u5e8a',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: kSpace6),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('\u6dfb\u52a0\u95f9\u949f'),
            ),
          ],
        ),
      ),
    );
  }
}
