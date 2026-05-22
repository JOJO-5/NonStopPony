import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const Color _kAccent = Color(0xFFE8936A);

/// Three-wheel HH: MM : SS picker for timer duration.
///
/// Uses [CupertinoTimerPicker] in count-up mode so the user can freely
/// dial any duration. The selected [Duration] is reported via [onChanged].
class TimerPicker extends StatefulWidget {
  final Duration initial;
  final ValueChanged<Duration> onChanged;

  const TimerPicker({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  @override
  State<TimerPicker> createState() => _TimerPickerState();
}

class _TimerPickerState extends State<TimerPicker> {
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _duration = widget.initial;
  }

  @override
  void didUpdateWidget(covariant TimerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      _duration = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CupertinoTheme(
        data: CupertinoThemeData(
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _kAccent,
            ),
          ),
        ),
        child: CupertinoTimerPicker(
          mode: CupertinoTimerPickerMode.hms,
          initialTimerDuration: _duration,
          onTimerDurationChanged: (d) {
            _duration = d;
            widget.onChanged(d);
          },
        ),
      ),
    );
  }
}