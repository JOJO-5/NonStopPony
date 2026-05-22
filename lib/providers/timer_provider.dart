import 'dart:async';
import 'package:flutter/foundation.dart';

enum TimerState { idle, running, paused, finished }

class TimerProvider extends ChangeNotifier {
  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  TimerState _state = TimerState.idle;
  Timer? _timer;
  DateTime? _startedAt;
  int _elapsedSeconds = 0; // seconds elapsed before pause

  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;
  TimerState get state => _state;

  String get formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get progress {
    if (_totalSeconds == 0) return 0.0;
    return _remainingSeconds / _totalSeconds;
  }

  void setDuration(int seconds) {
    if (_state != TimerState.idle && _state != TimerState.finished) return;
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    _state = TimerState.idle;
    notifyListeners();
  }

  void start() {
    if (_remainingSeconds <= 0) return;
    _state = TimerState.running;
    _startedAt = DateTime.now();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    notifyListeners();
  }

  void _onTick(Timer timer) {
    if (_state != TimerState.running) return;
    _remainingSeconds--;
    notifyListeners();

    if (_remainingSeconds <= 0) {
      _remainingSeconds = 0;
      _state = TimerState.finished;
      _timer?.cancel();
      _timer = null;
      notifyListeners();
    }
  }

  void pause() {
    if (_state != TimerState.running) return;
    _state = TimerState.paused;
    _elapsedSeconds = _totalSeconds - _remainingSeconds;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void resume() {
    if (_state != TimerState.paused) return;
    _state = TimerState.running;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = _totalSeconds;
    _state = TimerState.idle;
    _elapsedSeconds = 0;
    notifyListeners();
  }

  void addMinute() {
    if (_state != TimerState.running && _state != TimerState.paused) return;
    _remainingSeconds += 60;
    _totalSeconds += 60;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}