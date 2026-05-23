import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/timer_background_service.dart';

enum TimerState { idle, running, paused, finished }

class TimerProvider extends ChangeNotifier {
  TimerProvider() {
    _initFromPrefs();
  }

  static const _keyEndTime = 'timer_end_time';
  static const _keyTotalSeconds = 'timer_total_seconds';

  int _totalSeconds = 0;
  int _remainingSeconds = 0;
  TimerState _state = TimerState.idle;
  Timer? _timer;
  DateTime? _endTime;

  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;
  TimerState get state => _state;

  String get formattedTime {
    final hours = (_remainingSeconds ~/ 3600);
    final minutes = ((_remainingSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  double get progress {
    if (_totalSeconds == 0) return 0.0;
    // Elapsed time ratio (0→1): ring fills clockwise from top
    return (_totalSeconds - _remainingSeconds) / _totalSeconds;
  }

  void setDuration(int seconds) {
    if (_state != TimerState.idle && _state != TimerState.finished) return;
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    _state = TimerState.idle;
    _endTime = null;
    notifyListeners();
  }

  void start() {
    if (_remainingSeconds <= 0) return;
    _state = TimerState.running;

    // Calculate the absolute end time so we can sync after background pauses
    _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    // Persist endTime so timer survives process kill
    _persistTimer();

    // Schedule a native AlarmManager alarm at the end time as a fallback
    // for when the app is in the background / device is in Doze mode
    TimerBackgroundService.scheduleTimerAlarm(
      _endTime!.millisecondsSinceEpoch,
    );

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
      _endTime = null;
      _clearPersistedTimer();
      // Cancel the native timer alarm since the Flutter-side timer
      // completed normally (no need for the native fallback)
      TimerBackgroundService.cancelTimerAlarm();
      notifyListeners();
    }
  }

  /// Syncs the remaining seconds from the stored [_endTime].
  /// Called when the app resumes from background to correct any drift
  /// caused by the Dart Timer being paused during Doze/background.
  void syncFromEndTime() {
    if (_endTime == null || _state != TimerState.running) return;
    final now = DateTime.now();
    if (now.isAfter(_endTime!)) {
      // Timer should have finished while in background
      _remainingSeconds = 0;
      _state = TimerState.finished;
      _timer?.cancel();
      _timer = null;
      _endTime = null;
      TimerBackgroundService.cancelTimerAlarm();
    } else {
      _remainingSeconds = _endTime!.difference(now).inSeconds;
    }
    notifyListeners();
  }

  void pause() {
    if (_state != TimerState.running) return;
    _state = TimerState.paused;
    _timer?.cancel();
    _timer = null;
    // Cancel the native alarm while paused — it will be rescheduled on resume
    TimerBackgroundService.cancelTimerAlarm();
    notifyListeners();
  }

  void resume() {
    if (_state != TimerState.paused) return;
    _state = TimerState.running;

    // Recalculate end time from remaining seconds
    _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    // Persist updated endTime
    _persistTimer();

    // Reschedule the native alarm at the new end time
    TimerBackgroundService.scheduleTimerAlarm(
      _endTime!.millisecondsSinceEpoch,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _remainingSeconds = _totalSeconds;
    _state = TimerState.idle;
    _endTime = null;
    _clearPersistedTimer();
    TimerBackgroundService.cancelTimerAlarm();
    notifyListeners();
  }

  void addMinute() {
    if (_state != TimerState.running && _state != TimerState.paused) return;
    _remainingSeconds += 60;
    _totalSeconds += 60;
    // Extend the end time by 60 seconds if running
    if (_state == TimerState.running && _endTime != null) {
      _endTime = _endTime!.add(const Duration(seconds: 60));
      _persistTimer();
      TimerBackgroundService.scheduleTimerAlarm(
        _endTime!.millisecondsSinceEpoch,
      );
    }
    notifyListeners();
  }

  /// Persists [endTime] and [totalSeconds] to SharedPreferences so the timer
  /// can survive an app process kill and be recovered on next launch.
  Future<void> _persistTimer() async {
    if (_endTime == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyEndTime, _endTime!.millisecondsSinceEpoch);
    await prefs.setInt(_keyTotalSeconds, _totalSeconds);
  }

  /// Clears persisted timer state from SharedPreferences.
  Future<void> _clearPersistedTimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEndTime);
    await prefs.remove(_keyTotalSeconds);
  }

  /// Recovers timer state from SharedPreferences on provider creation.
  /// If a saved [endTime] is in the future, restores the timer to running state.
  Future<void> _initFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final endTimeMs = prefs.getInt(_keyEndTime);
      final totalSecs = prefs.getInt(_keyTotalSeconds);
      if (endTimeMs == null || totalSecs == null) return;
      final endTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);
      final now = DateTime.now();
      if (endTime.isBefore(now)) {
        // Timer already expired while app was dead — clear stale state
        await _clearPersistedTimer();
        return;
      }
      // Recover the timer: it was running when the app was killed
      _totalSeconds = totalSecs;
      _remainingSeconds = endTime.difference(now).inSeconds;
      if (_remainingSeconds <= 0) {
        _remainingSeconds = 0;
        _state = TimerState.finished;
        await _clearPersistedTimer();
      } else {
        _state = TimerState.running;
        _endTime = endTime;
        // Resume the Dart timer tick
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
        // Ensure native AlarmManager fallback is scheduled
        TimerBackgroundService.scheduleTimerAlarm(endTimeMs);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('TimerProvider._initFromPrefs error: $e');
      await _clearPersistedTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    TimerBackgroundService.cancelTimerAlarm();
    super.dispose();
  }
}