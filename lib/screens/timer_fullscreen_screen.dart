import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/analog_clock_widget.dart';
import '../app.dart';

/// Full-screen timer overlay for lock-screen / screen-off state.
/// Supports swipe-up to dismiss gesture in addition to button control.
/// Clock face has a soft breathing glow; no intrusive animations.
class TimerFullScreenScreen extends StatefulWidget {
  const TimerFullScreenScreen({super.key});

  static Future<bool> push(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<bool>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => const TimerFullScreenScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((v) => v ?? false);
  }

  @override
  State<TimerFullScreenScreen> createState() => _TimerFullScreenScreenState();
}

class _TimerFullScreenScreenState extends State<TimerFullScreenScreen>
    with TickerProviderStateMixin {
  late AnimationController _swipeCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late Timer _timer;
  DateTime _now = DateTime.now();

  static const _bg = Color(0xFF120A06);
  static const _accent = Color(0xFFE8936A);
  static const _swipeThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Swipe-up progress animation (functional, not decorative)
    _swipeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    // Soft breathing glow around the clock face
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.08, end: 0.35).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _swipeCtrl.dispose();
    _glowCtrl.dispose();
    _timer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismiss() async {
    const channel = MethodChannel('com.example.alarm_clock/timer_background');
    try {
      await channel.invokeMethod('stopTimerRing');
    } catch (_) {}
    if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final dateStr = _fmtDate(_now);

    return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: GestureDetector(
            onTap: _dismiss,
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < 0) {
                final progress = (_swipeCtrl.value + (-details.delta.dy / _swipeThreshold)).clamp(0.0, 1.0);
                _swipeCtrl.value = progress;
              }
            },
            onVerticalDragEnd: (details) {
              if (_swipeCtrl.value > 0.6) {
                _dismiss();
              } else {
                _swipeCtrl.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
              }
            },
            child: Stack(
              children: [
                // ── Swipe-up overlay (fade in as user swipes) ──
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _swipeCtrl,
                    builder: (_, _) => IgnorePointer(
                      child: Container(
                        color: _accent.withValues(alpha: _swipeCtrl.value * 0.3),
                      ),
                    ),
                  ),
                ),

                // ── Static content column (fills screen with Positioned.fill) ──
                Positioned.fill(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top: date + label
                    Padding(
                      padding: const EdgeInsets.only(top: kSpace12),
                      child: Column(
                        children: [
                          Text(dateStr,
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 15,
                                  letterSpacing: 1)),
                          const SizedBox(height: 6),
                          const Text(
                            '计时完成',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),

                    // Center: clock face with breathing glow
                    AnimatedBuilder(
                      animation: _glowCtrl,
                      builder: (_, _) => Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E1008),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: _glowAnim.value),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnalogClockWidget(
                            size: 168,
                            faceColor: const Color(0xFF1E1008),
                            handColor: Colors.white,
                            accentColor: _accent,
                          ),
                        ),
                      ),
                    ),

                    // Bottom: time + swipe hint + dismiss button
                    Padding(
                      padding: const EdgeInsets.only(bottom: kSpace12),
                      child: Column(
                        children: [
                          Text(timeStr,
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 3)),
                          const SizedBox(height: kSpace6),
                          const Text('时间到',
                              style: TextStyle(
                                  color: Colors.white24,
                                  fontSize: 13,
                                  letterSpacing: 1)),
                          const SizedBox(height: kSpace10),
                          // Swipe-up hint
                          AnimatedBuilder(
                            animation: _swipeCtrl,
                            builder: (_, _) => Opacity(
                              opacity: 1.0 - _swipeCtrl.value * 0.5,
                              child: Column(
                                children: [
                                  Icon(Icons.keyboard_arrow_up,
                                      color: _accent.withValues(alpha: 0.6 + _swipeCtrl.value * 0.4),
                                      size: 28),
                                  Text('上划关闭',
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
                          // Dismiss button
                          GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _accent,
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: 0.5),
                                    blurRadius: 30,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(height: kSpace5),
                          const Text('关闭',
                              style: TextStyle(
                                  color: Colors.white24, fontSize: 12)),
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
    );
  }

  String _fmtDate(DateTime dt) {
    const wd = ['一', '二', '三', '四', '五', '六', '日'];
    return '${dt.month}月${dt.day}日 星期${wd[dt.weekday - 1]}';
  }
}
