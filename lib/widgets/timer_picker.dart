import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app.dart';

/// Three-wheel HH : MM : SS picker for timer duration, styled like the alarm
/// time picker with magnifier + looping for a smooth feel.
///
/// Respects dark mode via [Theme].
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
  late int _hours;
  late int _minutes;
  late int _seconds;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _secondController;

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _hours = d.inHours;
    _minutes = d.inMinutes.remainder(60);
    _seconds = d.inSeconds.remainder(60);
    _hourController = FixedExtentScrollController(initialItem: _hours);
    _minuteController = FixedExtentScrollController(initialItem: _minutes);
    _secondController = FixedExtentScrollController(initialItem: _seconds);
  }

  @override
  void didUpdateWidget(covariant TimerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial) {
      final d = widget.initial;
      _hours = d.inHours;
      _minutes = d.inMinutes.remainder(60);
      _seconds = d.inSeconds.remainder(60);
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(Duration(hours: _hours, minutes: _minutes, seconds: _seconds));
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : Colors.white;

    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _Wheel(
            controller: _hourController,
            itemCount: 100,
            label: (i) => i.toString().padLeft(2, '0'),
            onChanged: (i) { _hours = i; _emit(); },
          )),
          _Colon(),
          Expanded(child: _Wheel(
            controller: _minuteController,
            itemCount: 60,
            label: (i) => i.toString().padLeft(2, '0'),
            onChanged: (i) { _minutes = i; _emit(); },
          )),
          _Colon(),
          Expanded(child: _Wheel(
            controller: _secondController,
            itemCount: 60,
            label: (i) => i.toString().padLeft(2, '0'),
            onChanged: (i) { _seconds = i; _emit(); },
          )),
        ],
      ),
    );
  }
}

class _Colon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w300,
          color: kBrandCopper,
          height: 1.0,
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) label;
  final ValueChanged<int> onChanged;

  const _Wheel({
    required this.controller,
    required this.itemCount,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) => true,
      child: CupertinoPicker(
        scrollController: controller,
        itemExtent: 44,
        diameterRatio: 1.2,
        squeeze: 1.0,
        useMagnifier: true,
        magnification: 1.15,
        offAxisFraction: 0.0,
        looping: true,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: kBrandCopper.withValues(alpha: 0.08),
        ),
        onSelectedItemChanged: onChanged,
        children: List<Widget>.generate(itemCount, (index) {
          return Center(
            child: Text(
              label(index),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: kBrandTextPrimary,
                letterSpacing: -0.5,
              ),
            ),
          );
        }),
      ),
    );
  }
}
