import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/analog_clock_widget.dart';
import '../services/alarm_notification_service.dart';
import '../app.dart';

/// Full-screen alarm overlay for lock-screen / screen-off state.
class AlarmFullScreenScreen extends StatefulWidget {
  final int alarmId;
  final String label;

  const AlarmFullScreenScreen({super.key, required this.alarmId, required this.label});

  static Future<void> push(BuildContext context, {required int alarmId, required String label}) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => AlarmFullScreenScreen(alarmId: alarmId, label: label),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
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
  late AnimationController _slideCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;
  late Animation<double> _slideAnim;
  late Timer _timer;
  DateTime _now = DateTime.now();

  static const _bg = Color(0xFF120A06);

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

    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          Future.delayed(const Duration(milliseconds: 100), () => _slideCtrl.reverse());
        }
      });
    _slideCtrl.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _slideCtrl.dispose();
    _timer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismiss() async {
    // Bug #2 fix: stop the ringing service when user dismisses the alarm
    await AlarmNotificationService.stopAlarmRing();
    await AlarmNotificationService().cancelAlarmNotification(widget.alarmId);
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
          child: Stack(
            children: [
              // ── Ambient glow ───────────────────────────────
              Center(
                child: AnimatedBuilder(
                  animation: _rippleAnim,
                  builder: (_, __) => Container(
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

              // ── Content column ──────────────────────────────
              Column(
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

                  // Center: pulsing clock
                  AnimatedBuilder(
                    animation: Listenable.merge([_pulseAnim, _rippleAnim]),
                    builder: (_, __) => Stack(
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

                  // Bottom: time + dismiss
                  Padding(
                    padding: const EdgeInsets.only(bottom: kSpace12),
                    child: Column(
                      children: [
                        Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 3)),
                        const SizedBox(height: kSpace6),
                        Text('\u95f9\u949f\u54cd\u4e86', style: const TextStyle(color: Colors.white24, fontSize: 13, letterSpacing: 1)),
                        const SizedBox(height: kSpace5),
                        // Dismiss button
                        SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(_slideAnim),
                          child: GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kBrandCopper,
                                boxShadow: [
                                  BoxShadow(color: kBrandCopper.withValues(alpha: 0.5), blurRadius: 30, spreadRadius: 6),
                                ],
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white, size: 36),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpace3),
                        Text('\u70b9\u51fb\u5173\u95ed', style: const TextStyle(color: Colors.white24, fontSize: 12)),
                        const SizedBox(height: kSpace4),
                        // Snooze button
                        SlideTransition(
                          position: Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(_slideAnim),
                          child: GestureDetector(
                            onTap: _snooze,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: kBrandCopper, width: 2),
                              ),
                              child: const Icon(Icons.snooze_rounded, color: kBrandCopper, size: 36),
                            ),
                          ),
                        ),
                        const SizedBox(height: kSpace3),
                        Text('\u7a0d\u540e\u63d0\u9192', style: const TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
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
