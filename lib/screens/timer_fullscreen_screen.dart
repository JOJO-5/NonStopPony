import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/analog_clock_widget.dart';
import '../app.dart';

/// Full-screen timer overlay for lock-screen / screen-off state.
/// Supports swipe-up to dismiss gesture in addition to button control.
/// Uses the same visual style as the alarm full-screen (clock face + shake).
class TimerFullScreenScreen extends StatefulWidget {
  const TimerFullScreenScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => const TimerFullScreenScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  State<TimerFullScreenScreen> createState() => _TimerFullScreenScreenState();
}

class _TimerFullScreenScreenState extends State<TimerFullScreenScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _vibCtrl1;
  late AnimationController _vibCtrl2;
  late AnimationController _swipeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _rippleAnim;
  late Animation<double> _vibAnim1;
  late Animation<double> _vibAnim2;
  late Timer _timer;
  DateTime _now = DateTime.now();

  static const _bg = Color(0xFF120A06);
  static const _accent = Color(0xFFE8936A);
  static const _swipeThreshold = 120.0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _rippleAnim = Tween<double>(begin: 0.6, end: 1.5).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    // Vibration wave tremor — two overlapping frequencies create a
    // natural "buzzing" effect like an alarm clock, no directional slide.
    _vibCtrl1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 60),
    )..repeat(reverse: true);
    _vibAnim1 = Tween<double>(begin: -2.5, end: 2.5).animate(
      CurvedAnimation(parent: _vibCtrl1, curve: Curves.easeInOut),
    );

    _vibCtrl2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
    )..repeat(reverse: true);
    _vibAnim2 = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _vibCtrl2, curve: Curves.easeInOut),
    );

    // Swipe-up progress animation
    _swipeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _vibCtrl1.dispose();
    _vibCtrl2.dispose();
    _swipeCtrl.dispose();
    _timer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismiss() async {
    // Stop the timer ringing service via native channel
    const channel = MethodChannel('com.example.alarm_clock/timer_background');
    try {
      await channel.invokeMethod('stopTimerRing');
    } catch (_) {}
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final dateStr = _fmtDate(_now);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: GestureDetector(
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
                            _accent
                                .withValues(alpha: 0.12 * (1.5 - _rippleAnim.value).clamp(0.0, 1.0)),
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
                  builder: (_, __) => IgnorePointer(
                    child: Container(
                      color: _accent.withValues(alpha: _swipeCtrl.value * 0.3),
                    ),
                  ),
                ),

                // ── Vibration tremor + content column ──
                AnimatedBuilder(
                  animation: Listenable.merge([_vibAnim1, _vibAnim2]),
                  builder: (_, child) => Transform.translate(
                    offset: Offset(_vibAnim1.value + _vibAnim2.value, 0),
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

                      // Center: pulsing clock face (same as alarm)
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
                                  border: Border.all(color: _accent, width: 1.5),
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
                                    BoxShadow(
                                      color: _accent.withValues(alpha: 0.25),
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
                          ],
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
                              builder: (_, __) => Opacity(
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
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    const wd = ['一', '二', '三', '四', '五', '六', '日'];
    return '${dt.month}月${dt.day}日 星期${wd[dt.weekday - 1]}';
  }
}
