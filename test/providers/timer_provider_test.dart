import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm_clock/providers/timer_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('com.example.alarm_clock/timer_background'),
            (call) async => null);
  });

  test('pause 清除持久化的 endTime，进程重启后不会恢复成 running', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = TimerProvider();
    await pumpEventQueue(); // 等待 _initFromPrefs 完成
    provider.setDuration(60);
    provider.start();
    await pumpEventQueue(); // 等待 _persistTimer 写入
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('timer_end_time'), isNotNull);

    provider.pause();
    await pumpEventQueue();
    expect(prefs.getInt('timer_end_time'), isNull);
    expect(prefs.getInt('timer_total_seconds'), isNull);

    provider.dispose();
  });
}
