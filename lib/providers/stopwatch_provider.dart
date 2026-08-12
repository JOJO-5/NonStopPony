import 'dart:async';
import 'package:flutter/foundation.dart';

enum StopwatchState { idle, running, paused }

class Lap {
  final int index;
  final Duration elapsed;    // total elapsed time at this lap
  final Duration lapTime;    // time since previous lap

  const Lap({
    required this.index,
    required this.elapsed,
    required this.lapTime,
  });

  Lap copyWith({int? index, Duration? elapsed, Duration? lapTime}) {
    return Lap(
      index: index ?? this.index,
      elapsed: elapsed ?? this.elapsed,
      lapTime: lapTime ?? this.lapTime,
    );
  }
}

class StopwatchProvider extends ChangeNotifier {
  Duration _elapsed = Duration.zero;
  StopwatchState _state = StopwatchState.idle;
  final List<Lap> _laps = [];
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsedBeforePause = Duration.zero;

  Duration get elapsed => _elapsed;
  StopwatchState get state => _state;
  List<Lap> get laps => List.unmodifiable(_laps);

  String get formattedTime => StopwatchProvider.format(_elapsed);

  /// Formats a duration as stopwatch display text.
  /// Under 1 hour: MM:SS.cc. 1 hour or more: HH:MM:SS.cc.
  @visibleForTesting
  static String format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final cents = (d.inMilliseconds ~/ 10) % 100;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    final cc = cents.toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$mm:$ss.$cc';
    }
    return '$mm:$ss.$cc';
  }

  /// Returns the index of the best (fastest) lap, or -1 if no laps
  int get bestLapIndex {
    if (_laps.isEmpty) return -1;
    var best = 0;
    for (var i = 1; i < _laps.length; i++) {
      if (_laps[i].lapTime < _laps[best].lapTime) {
        best = i;
      }
    }
    return best;
  }

  void start() {
    if (_state == StopwatchState.running) return;
    _state = StopwatchState.running;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 30), _updateElapsed);
    notifyListeners();
  }

  void _updateElapsed(Timer timer) {
    if (_startedAt == null) return;
    _elapsed = _elapsedBeforePause + DateTime.now().difference(_startedAt!);
    notifyListeners();
  }

  void pause() {
    if (_state != StopwatchState.running) return;
    _state = StopwatchState.paused;
    _elapsedBeforePause = _elapsed;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _elapsed = Duration.zero;
    _elapsedBeforePause = Duration.zero;
    _laps.clear();
    _state = StopwatchState.idle;
    _startedAt = null;
    notifyListeners();
  }

  void lap() {
    if (_state != StopwatchState.running) return;
    final previousElapsed = _laps.isEmpty ? Duration.zero : _laps.last.elapsed;
    _laps.add(Lap(
      index: _laps.length + 1,
      elapsed: _elapsed,
      lapTime: _elapsed - previousElapsed,
    ));
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}