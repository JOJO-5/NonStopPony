import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app.dart';

class MathChallenge extends StatefulWidget {
  final VoidCallback onSolved;
  final int problemCount;
  const MathChallenge({super.key, required this.onSolved, this.problemCount = 3});

  @override
  State<MathChallenge> createState() => _MathChallengeState();
}

class _MathChallengeState extends State<MathChallenge> {
  final _controller = TextEditingController();
  final _random = Random();
  late int _solved;
  late int _a, _b;
  late String _answer;

  @override
  void initState() {
    super.initState();
    _solved = 0;
    _genProblem();
    _controller.addListener(_check);
  }

  @override
  void dispose() {
    _controller.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  void _genProblem() {
    _a = 1 + _random.nextInt(20);
    _b = 1 + _random.nextInt(20);
    _answer = (_a + _b).toString();
    _controller.clear();
  }

  void _check() {
    if (_controller.text == _answer) {
      _solved++;
      if (_solved >= widget.problemCount) {
        widget.onSolved();
      } else {
        setState(_genProblem);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('解算术题关闭闹钟',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.problemCount, (i) => Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(_solved > i ? Icons.circle : Icons.circle_outlined,
                  color: kBrandCopper, size: 12),
            )),
          ),
          const SizedBox(height: 24),
          Text('$_a + $_b = ?',
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w300)),
          const SizedBox(height: 16),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _controller,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 36),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: '?',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 36),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kBrandCopper.withValues(alpha: 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: kBrandCopper.withValues(alpha: 0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBrandCopper, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
