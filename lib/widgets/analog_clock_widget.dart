import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// An animated analog clock face that ticks every second.
///
/// Used in both the full-screen lock-screen alarm overlay and the
/// banner notification. The clock hands animate with smooth sweeping
/// motion using [AnimationController].
class AnalogClockWidget extends StatefulWidget {
  final double size;
  final Color faceColor;
  final Color handColor;
  final Color accentColor;

  const AnalogClockWidget({
    super.key,
    this.size = 160,
    this.faceColor = Colors.white,
    this.handColor = const Color(0xFF2C1810),
    this.accentColor = const Color(0xFFE8936A),
  });

  @override
  State<AnalogClockWidget> createState() => _AnalogClockWidgetState();
}

class _AnalogClockWidgetState extends State<AnalogClockWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _ClockPainter(
            now: _now,
            faceColor: widget.faceColor,
            handColor: widget.handColor,
            accentColor: widget.accentColor,
          ),
        );
      },
    );
  }
}

class _ClockPainter extends CustomPainter {
  final DateTime now;
  final Color faceColor;
  final Color handColor;
  final Color accentColor;

  _ClockPainter({
    required this.now,
    required this.faceColor,
    required this.handColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── Face ──────────────────────────────────────────────────
    final facePaint = Paint()..color = faceColor;
    canvas.drawCircle(center, radius, facePaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 1.5, ringPaint);

    // ── Hour tick marks ───────────────────────────────────────
    final tickPaint = Paint()
      ..color = handColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final majorTickPaint = Paint()
      ..color = handColor.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final angle = (i / 60) * 2 * pi - pi / 2;
      final isMajor = i % 5 == 0;
      final inner = radius - (isMajor ? 12 : 6);
      final outer = radius - 4;
      canvas.drawLine(
        Offset(center.dx + inner * cos(angle), center.dy + inner * sin(angle)),
        Offset(center.dx + outer * cos(angle), center.dy + outer * sin(angle)),
        isMajor ? majorTickPaint : tickPaint,
      );
    }

    // ── Hour hand ─────────────────────────────────────────────
    final hourAngle =
        ((now.hour % 12 + now.minute / 60) / 12) * 2 * pi - pi / 2;
    _drawHand(canvas, center, hourAngle, radius * 0.5, 4.5, handColor);

    // ── Minute hand ───────────────────────────────────────────
    final minuteAngle =
        ((now.minute + now.second / 60) / 60) * 2 * pi - pi / 2;
    _drawHand(canvas, center, minuteAngle, radius * 0.7, 3, handColor);

    // ── Second hand ───────────────────────────────────────────
    final secondAngle = (now.second / 60) * 2 * pi - pi / 2;
    _drawHand(canvas, center, secondAngle, radius * 0.75, 1.5, accentColor);

    // Tail of second hand
    _drawHand(canvas, center, secondAngle + pi, radius * 0.2, 1.5, accentColor);

    // Center dot
    canvas.drawCircle(center, 5, Paint()..color = accentColor);
    canvas.drawCircle(center, 3, Paint()..color = faceColor);
  }

  void _drawHand(Canvas canvas, Offset center, double angle, double length,
      double width, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx + length * cos(angle), center.dy + length * sin(angle)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.now.second != now.second;
}
