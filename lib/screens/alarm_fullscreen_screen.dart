import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/analog_clock_widget.dart';
import '../widgets/tasks/math_challenge.dart';
import '../services/alarm_notification_service.dart';
import '../services/alarm_scheduler_service.dart';
import '../services/alarm_storage_service.dart';
import '../services/schedule_storage_service.dart';
import '../models/alarm_info.dart';
import '../app.dart';

/// Full-screen alarm overlay for lock-screen / screen-off state.
/// Supports swipe-up to dismiss gesture in addition to button controls.
class AlarmFullScreenScreen extends StatefulWidget {
  final int alarmId;
  final String label;

  const AlarmFullScreenScreen({super.key, required this.alarmId, required this.label});

  static Future<void> push(BuildContext context, {required int alarmId, required String label}) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => AlarmFullScreenScreen(alarmId: alarmId, label: label),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  State<AlarmFullScreenScreen> createState() => _AlarmFullScreenScreenState();
}

class _AlarmFullScreenScreenState extends State<AlarmFullScreenScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _swipeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;
  late Animation<double> _shakeAnim;
  late Timer _timer;
  DateTime _now = DateTime.now();
  AlarmTaskType _taskType = AlarmTaskType.none;
  bool _taskCompleted = false;
  static const _bg = Color(0xFF120A06);
  static const _swipeThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _rippleAnim = Tween<double>(begin: 0.6, end: 1.5).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    // Screen shake / vibration effect — fast, subtle, continuous
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))
      ..repeat(reverse: true);
    _shakeAnim = Tween<double>(begin: -2.5, end: 2.5).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut),
    );

    // Swipe-up progress animation
    _swipeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Load alarm from DB to get taskType (needed for MathChallenge)
    _loadAlarmTaskType();
  }
  Future<void> _loadAlarmTaskType() async {
    try {
      final alarm = await AlarmStorageService.getById(widget.alarmId);
      if (alarm != null && mounted) {
        setState(() => _taskType = alarm.taskType);
      }
    } catch (e) {
      debugPrint('Failed to load alarm taskType: $e');
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _shakeCtrl.dispose();
    _swipeCtrl.dispose();
    _timer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismiss() async {
    await AlarmNotificationService.stopAlarmRing();
    await AlarmNotificationService().cancelAlarmNotification(widget.alarmId);
    
    // Reschedule next alarm for repeating alarms (daily, weekdays, singleRest, etc.)
    try {
      final alarm = await AlarmStorageService.getById(widget.alarmId);
      if (alarm != null && alarm.repeatType != RepeatType.once) {
        final overrides = await ScheduleStorageService.getAll();
        await AlarmSchedulerService.scheduleAlarm(alarm, overrides: overrides);
        debugPrint('Rescheduled repeating alarm ${alarm.id} for next trigger');
      }
    } catch (e) {
      debugPrint('Failed to reschedule alarm after dismiss: $e');
    }
    
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _snooze() async {
    await AlarmNotificationService.stopAlarmRing();
    await AlarmNotificationService().snoozeAlarm(widget.alarmId, '战马闹钟', widget.label);
    if (mounted) Navigator.of(context, rootNavigator: true).pop('snooze');
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final dateStr = _fmtDate(_now);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              // Disable swipe-to-dismiss during math challenge
              if (_taskType == AlarmTaskType.math && !_taskCompleted) return;
              if (details.delta.dy < 0) {
                // Swiping up
                final progress = (_swipeCtrl.value + (-details.delta.dy / _swipeThreshold)).clamp(0.0, 1.0);
                _swipeCtrl.value = progress;
              }
            },
            onVerticalDragEnd: (details) {
              if (_taskType == AlarmTaskType.math && !_taskCompleted) return;
              if (_swipeCtrl.value > 0.6) {
                // Threshold reached — dismiss
                _dismiss();
              } else {
                // Snap back
                _swipeCtrl.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              }
            },
            child: Stack(
              children: [
                // ── Ambient glow ───────────────────────────────
                Center(
                  child: AnimatedBuilder(
                    animation: _rippleAnim,
                    builder: (_, _) => Container(
                      width: 280 * _rippleAnim.value,
                      height: 280 * _rippleAnim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            kBrandCopper.withValues(alpha: 0.12 * (1.5 - _rippleAnim.value).clamp(0.0, 1.0)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Swipe-up overlay (fade in as user swipes) ──
                AnimatedBuilder(
                  animation: _swipeCtrl,
                  builder: (_, _) => IgnorePointer(
                    child: Container(
                      color: kBrandCopper.withValues(alpha: _swipeCtrl.value * 0.3),
                    ),
                  ),
                ),

                // ── Shake + content column ──────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_shakeAnim.value, 0),
                    child: child,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top: date + label
                      Padding(
                        padding: const EdgeInsets.only(top: kSpace12),
                        child: Column(
                          children: [
                            Text(dateStr, style: const TextStyle(color: Colors.white38, fontSize: 15, letterSpacing: 1)),
                            const SizedBox(height: 6),
                            Text(
                              widget.label,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),

                      // Center: pulsing clock (Expanded to shrink when keyboard appears)
                      Expanded(
                        child: Center(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_pulseAnim, _rippleAnim]),
                            builder: (_, _) => Stack(
                              alignment: Alignment.center,
                              children: [
                                // Ripple ring
                                Opacity(
                                  opacity: (1.5 - _rippleAnim.value).clamp(0.0, 0.4),
                                  child: Container(
                                    width: 240 * _rippleAnim.value,
                                    height: 240 * _rippleAnim.value,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: kBrandCopper, width: 1.5),
                                    ),
                                  ),
                                ),
                                // Pulsing clock face
                                ScaleTransition(
                                  scale: _pulseAnim,
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1E1008),
                                      boxShadow: [
                                        BoxShadow(color: kBrandCopper.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 10),
                                      ],
                                    ),
                                    child: Center(
                                      child: AnalogClockWidget(
                                        size: 168,
                                        faceColor: const Color(0xFF1E1008),
                                        handColor: Colors.white,
                                        accentColor: kBrandCopper,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Bottom: time + task or buttons
                      Padding(
                        padding: const EdgeInsets.only(bottom: kSpace12),
                        child: Column(
                          children: [
                            Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 3)),
                            const SizedBox(height: kSpace6),
                            // ── Math challenge mode ────────────────────
                            if (_taskType == AlarmTaskType.math && !_taskCompleted) ...[
                              const SizedBox(height: kSpace4),
                              MathChallenge(
                                onSolved: () {
                                  setState(() => _taskCompleted = true);
                                  _dismiss();
                                },
                              ),
                            ] else ...[
                              const Text('闹钟响了', style: TextStyle(color: Colors.white24, fontSize: 13, letterSpacing: 1)),
                              const SizedBox(height: kSpace10),
                              // Swipe-up hint with animated arrow
                              AnimatedBuilder(
                                animation: _swipeCtrl,
                                builder: (_, _) => Opacity(
                                  opacity: 1.0 - _swipeCtrl.value * 0.5,
                                  child: Column(
                                    children: [
                                      Icon(Icons.keyboard_arrow_up,
                                          color: kBrandCopper.withValues(alpha: 0.6 + _swipeCtrl.value * 0.4),
                                          size: 28),
                                      const Text('上划关闭',
                                          style: TextStyle(
                                            color: Colors.white24,
                                            fontSize: 12,
                                            letterSpacing: 1,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: kSpace8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Snooze button
                                  GestureDetector(
                                    onTap: _snooze,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: kBrandCopper, width: 2),
                                      ),
                                      child: const Icon(Icons.snooze_rounded, color: kBrandCopper, size: 28),
                                    ),
                                  ),
                                  const SizedBox(width: kSpace10),
                                  // Dismiss button
                                  GestureDetector(
                                    onTap: _dismiss,
                                    child: Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: kBrandCopper,
                                        boxShadow: [
                                          BoxShadow(color: kBrandCopper.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 6),
                                        ],
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: kSpace5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('稍后提醒', style: TextStyle(color: Colors.white24, fontSize: 12)),
                                  const SizedBox(width: kSpace10),
                                  const Text('关闭', style: TextStyle(color: Colors.white24, fontSize: 12)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const wd = ['\u4e00', '\u4e8c', '\u4e09', '\u56db', '\u4e94', '\u516d', '\u65e5'];
    return '${dt.month}\u6708${dt.day}\u65e5 \u661f\u671f${wd[dt.weekday - 1]}';
  }
}
