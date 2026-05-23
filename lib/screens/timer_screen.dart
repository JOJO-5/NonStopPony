import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/timer_provider.dart';
import '../widgets/timer_picker.dart';
import '../widgets/timer_presets.dart';
import 'timer_fullscreen_screen.dart';

const Color _kAccent = Color(0xFFE8936A);
const Color _kBg = Color(0xFFFDF8F3);
const Color _kText = Color(0xFF3D2C2C);

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Duration _pickedDuration = const Duration(minutes: 5);
  late AnimationController _finishController;
  bool _hasPlayedFinishSound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _finishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finishController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<TimerProvider>();
      provider.syncFromEndTime();
    }
  }

  Future<void> _playFinishSound() async {
    if (_hasPlayedFinishSound) return;
    _hasPlayedFinishSound = true;

    HapticFeedback.heavyImpact();

    try {
      const channel = MethodChannel('com.example.alarm_clock/timer_background');
      await channel.invokeMethod('startTimerRing');
    } catch (e) {
      debugPrint('Timer ring start error: $e');
    }

    if (mounted && context.read<TimerProvider>().state == TimerState.finished) {
      final provider = context.read<TimerProvider>();
      final dismissed = await TimerFullScreenScreen.push(context);
      if (dismissed && mounted && provider.state == TimerState.finished) {
        _hasPlayedFinishSound = false;
        _finishController.reset();
        provider.reset();
      } else if (dismissed && mounted) {
        _hasPlayedFinishSound = false;
        _finishController.reset();
      }
    }
  }

  // ── Idle state ──────────────────────────────────────────────

  Widget _buildIdle(TimerProvider provider) {
    return Column(
      children: [
        const Spacer(),
        TimerPicker(
          key: ValueKey(_pickedDuration),
          initial: _pickedDuration,
          onChanged: (d) {
            setState(() => _pickedDuration = d);
            provider.setDuration(d.inSeconds);
          },
        ),
        const SizedBox(height: 20),
        TimerPresets(
          onSelected: (d) {
            setState(() => _pickedDuration = d);
            provider.setDuration(d.inSeconds);
          },
        ),
        const Spacer(),
        _StartButton(onTap: () {
          if (provider.remainingSeconds <= 0) {
            provider.setDuration(_pickedDuration.inSeconds);
          }
          provider.start();
        }),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Running / Paused state ─────────────────────────────────

  Widget _buildRunning(TimerProvider provider) {
    final isPaused = provider.state == TimerState.paused;
    return Column(
      children: [
        const SizedBox(height: 48),
        SizedBox(
          width: 260,
          height: 260,
          child: CustomPaint(
            painter: _ProgressRingPainter(
              progress: provider.progress,
              trackColor: const Color(0xFFF0EDE8),
              progressColor: _kAccent,
            ),
            child: Center(
              child: Text(
                provider.formattedTime,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: _kText,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isPaused ? '已暂停' : '计时中',
          style: TextStyle(
            fontSize: 16,
            color: _kText.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _CircleButton(
              icon: isPaused ? Icons.play_arrow : Icons.pause,
              label: isPaused ? '继续' : '暂停',
              onTap: isPaused ? provider.resume : provider.pause,
            ),
            const SizedBox(width: 32),
            _CircleButton(
              icon: Icons.refresh,
              label: isPaused ? '重置' : '取消',
              onTap: provider.reset,
              backgroundColor: Colors.white,
              foregroundColor: _kAccent,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ── Finished state ─────────────────────────────────────────

  Widget _buildFinished(TimerProvider provider) {
    _finishController.forward(from: 0);
    _playFinishSound();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: AnimatedBuilder(
              animation: _finishController,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 48,
                      color: _kAccent),
                  SizedBox(height: 8),
                  Text(
                    '00:00',
                    style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.bold,
                      color: _kText,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              builder: (context, child) {
                return CustomPaint(
                  painter: _ProgressRingPainter(
                    progress: 1.0,
                    trackColor: const Color(0xFFF0EDE8),
                    progressColor: _kAccent,
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _finishController,
                        curve: Curves.elasticOut,
                      ),
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '时间到!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _kAccent,
            ),
          ),
          const SizedBox(height: 32),
          _CircleButton(
            icon: Icons.check,
            label: '确定',
            onTap: () {
              _finishController.reset();
              _hasPlayedFinishSound = false;
              provider.reset();
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: _kBg,
          body: SafeArea(
            child: switch (provider.state) {
              TimerState.idle => _buildIdle(provider),
              TimerState.running => _buildRunning(provider),
              TimerState.paused => _buildRunning(provider),
              TimerState.finished => _buildFinished(provider),
            },
          ),
        );
      },
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────

class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _kAccent,
          boxShadow: [
            BoxShadow(
              color: Color(0x33E8936A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  const _CircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = _kAccent,
    this.foregroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: backgroundColor,
              border: backgroundColor == Colors.white
                  ? Border.all(color: _kAccent, width: 2)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 28, color: foregroundColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _kText.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress ring painter ─────────────────────────────────────

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final startAngle = -pi / 2;
      final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
