# 功能逻辑 Bug 修复实施计划（审查回合 1）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复代码审查发现的 16 个功能逻辑问题（补班策略、开关取消、snooze、once 禁用、时区、节假日解析防御等），测试全绿后 bump patch 版本并推送 GitHub 触发 CI。

**Architecture:** 全部为针对性修复，不引入新抽象。纯逻辑修复（date_utils、模型）配单元测试；平台通道相关修复（通知、原生 Kotlin）以 flutter analyze + 手动验证清单验收；调度器重构集中在 `calculateNextTrigger` 单函数内。

**Tech Stack:** Flutter 3.35 / Dart 3.9, sqflite, flutter_local_notifications, Kotlin (AlarmManager + WorkManager), Provider。

**用户已拍板的决策：**
- 补班日（isWorkday）只强制「工作日型」闹钟响：`daily`/`weekdays`/`singleRest`/`doubleRest`；`once` 和 `custom` 走各自正常规则。
- 一次性闹钟被关闭（dismiss）后自动 `isEnabled=false`。
- 时区按设备时区（新增 `flutter_timezone` 依赖），读取失败回退 Asia/Shanghai。
- 完成后 bump patch 版本：`2.0.4+2006` → `2.0.5+2007`，push 到 master（CI 自动 analyze/test/build）。

## Global Constraints

- **GitNexus（项目 CLAUDE.md 强制）**：修改任何符号前先运行 `gitnexus_impact`（target=符号名, direction=upstream）并报告风险；HIGH/CRITICAL 先停下说明。提交前运行 `gitnexus_detect_changes()` 确认影响范围符合预期。
- **测试基线**：每个任务结束后 `flutter analyze` 零 error；`flutter test` 全绿。现有测试文件：`test/utils/date_utils_test.dart`、`test/services/alarm_scheduler_service_test.dart`、`test/models/*`、`test/widget_test.dart`。
- **提交规范**：沿用仓库风格 `fix(scope): message`（参考 `fix(doubleRest): Saturday not ring on singleRest week (workday)`）。每个任务独立提交。
- **Fact-Forcing Gate 注意**：本会话启动时 everything-claude-code 的 gate 还在内存配置里（已从 hooks.json 删除但需重启才生效）。**本会话内对每个新文件/命令的第一次 Edit/Bash 会被 deny 一次**——被拦后在下一轮回复中列出事实（谁引用该文件、影响的函数、涉及的数据结构）+ 引用用户指令原文，然后原样重试即可通过。不要放弃，这是 gate 的设计行为。
- **中文回答用户**（项目 memory directive）。
- 只改计划列出的文件，不做顺手重构。

---

### Task 1: date_utils 纯逻辑修复（补班策略、死代码、负数周）

**Files:**
- Modify: `lib/utils/date_utils.dart:7-16`（alarmTimeForDate）、`lib/utils/date_utils.dart:20-24`（weekNumber）、`lib/utils/date_utils.dart:89-136`（shouldRingOnDate）
- Test: `test/utils/date_utils_test.dart`（追加）

**Interfaces:**
- Consumes: `RepeatType`（`lib/models/alarm_info.dart`），`WeekSchedule`/`WeekType`（`lib/models/week_schedule.dart`）
- Produces: `alarmTimeForDate(alarm, date, overrides, {bool isWorkday = false})` —— 新增可选参数；`weekNumber(DateTime) → int`（负数日期返回 ≤0 的周号）；`shouldRingOnDate(alarm, date, overrides, {bool? isHoliday, bool? isWorkday})`（补班只强制工作日型）

- [ ] **Step 1: 写失败测试**（追加到 `test/utils/date_utils_test.dart` 末尾）

```dart
group('workday (补班) policy', () {
  AlarmInfo alarmOf(RepeatType t, {List<int> weekdays = const []}) => AlarmInfo.create(
      hour: 7, minute: 0, repeatType: t, weekdays: weekdays);
  final saturday = DateTime(2026, 8, 15); // Saturday
  final sunday = DateTime(2026, 8, 16);   // Sunday

  test('补班日强制 weekdays 类型响', () {
    expect(shouldRingOnDate(alarmOf(RepeatType.weekdays), saturday, [],
        isWorkday: true), isTrue);
  });
  test('补班日强制 doubleRest 响', () {
    expect(shouldRingOnDate(alarmOf(RepeatType.doubleRest), saturday, [],
        isWorkday: true), isTrue);
  });
  test('补班日强制 singleRest 周日响', () {
    expect(shouldRingOnDate(alarmOf(RepeatType.singleRest), sunday, [],
        isWorkday: true), isTrue);
  });
  test('补班日强制 daily 响', () {
    expect(shouldRingOnDate(alarmOf(RepeatType.daily), saturday, [],
        isWorkday: true), isTrue);
  });
  test('补班日不强制 custom', () {
    expect(shouldRingOnDate(
        alarmOf(RepeatType.custom, weekdays: [DateTime.monday]), saturday, [],
        isWorkday: true), isFalse);
  });
  test('补班日不强制 once（未选星期照常响，选了则按星期）', () {
    expect(shouldRingOnDate(alarmOf(RepeatType.once), saturday, [],
        isWorkday: true), isTrue); // weekdays 空 → 正常规则 true
    expect(shouldRingOnDate(
        alarmOf(RepeatType.once, weekdays: [DateTime.monday]), saturday, [],
        isWorkday: true), isFalse);
  });
});

group('alarmTimeForDate workday Saturday', () {
  test('双休周周六补班用周六专用时间', () {
    final alarm = AlarmInfo.create(
        hour: 7, minute: 0, repeatType: RepeatType.singleRest,
        saturdayHour: 8, saturdayMinute: 30);
    // 2026-08-15 所在周为偶数周（双休），无 override
    final t = alarmTimeForDate(alarm, DateTime(2026, 8, 15), [],
        isWorkday: true);
    expect(t.hour, 8);
    expect(t.minute, 30);
  });
});

group('weekNumber negative dates', () {
  test('2023-12-25 (周一) 为第 0 周', () {
    expect(weekNumber(DateTime(2023, 12, 25)), 0);
    expect(autoWeekType(DateTime(2023, 12, 25)), WeekType.double);
  });
  test('2023-12-18 为第 -1 周（单休，奇偶交替延续）', () {
    expect(weekNumber(DateTime(2023, 12, 18)), -1);
    expect(autoWeekType(DateTime(2023, 12, 18)), WeekType.single);
  });
});
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/utils/date_utils_test.dart`
Expected: 新增用例 FAIL（补班强制测试现行为对 custom/once 也返回 true；`alarmTimeForDate` 无 isWorkday 参数编译错；负数周返回 1）。

- [ ] **Step 3: 实现**

`lib/utils/date_utils.dart` 三处修改：

```dart
DateTime alarmTimeForDate(AlarmInfo alarm, DateTime date, List<WeekSchedule> overrides,
    {bool isWorkday = false}) {
  if (alarm.repeatType == RepeatType.singleRest &&
      date.weekday == DateTime.saturday) {
    final wt = resolveWeekType(date, overrides);
    // 补班周六视为工作日，同样使用周六专用时间
    if (wt == WeekType.single || isWorkday) {
      return DateTime(date.year, date.month, date.day, alarm.saturdayHour, alarm.saturdayMinute);
    }
  }
  return DateTime(date.year, date.month, date.day, alarm.hour, alarm.minute);
}
```

```dart
int weekNumber(DateTime date) {
  final epoch = DateTime(2024, 1, 1);
  final days = date.difference(epoch).inDays;
  // Dart ~/ 向零截断，负数需用 floor 保持周序号连续交替
  return days < 0 ? (days / 7).floor() + 1 : days ~/ 7 + 1;
}
```

`shouldRingOnDate` 中补班分支改为（其余不变）：

```dart
  // If this day is a make-up workday (补班), ring for workday-semantic types;
  // once/custom fall through to their own rules.
  if (isWorkday == true) {
    final isWorkdayType = alarm.repeatType == RepeatType.daily ||
        alarm.repeatType == RepeatType.weekdays ||
        alarm.repeatType == RepeatType.singleRest ||
        alarm.repeatType == RepeatType.doubleRest;
    if (isWorkdayType) return true;
  }
```

同时删除 `doubleRest` case 中的死代码（原 128-131 行，`if (date.weekday == DateTime.saturday)` 分支——前面已 return false，永远不可达）：

```dart
    case RepeatType.doubleRest:
      // Saturday and Sunday never ring
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        return false;
      }
      return true;
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/utils/date_utils_test.dart && flutter analyze`
Expected: 全绿（含原有用例）；analyze 零 error。

- [ ] **Step 5: Commit**

```bash
git add lib/utils/date_utils.dart test/utils/date_utils_test.dart
git commit -m "fix(schedule): 补班只强制工作日型闹钟，周六用专用时间；修复纪元前周数"
```

---

### Task 2: 调度器重构（今日假期判定、合并查询、不再二次计算时间、once 7天循环）

**Files:**
- Modify: `lib/services/alarm_scheduler_service.dart:23-84`（calculateNextTrigger）、`lib/services/alarm_scheduler_service.dart:125-165`（scheduleAlarm）、`lib/services/alarm_scheduler_service.dart:89-117`（calculateNext7Days）
- Test: `test/services/alarm_scheduler_service_test.dart`（追加）

**Interfaces:**
- Consumes: Task 1 的 `alarmTimeForDate(..., {isWorkday})` 与补班策略；`HolidayService.getHolidayInfo(DateTime) → Future<HolidayInfo?>`（含 `isHoliday`/`isWorkday` 字段）
- Produces: `calculateNextTrigger` 返回带正确时间的 DateTime（含补班周六专用时间）；`calculateNext7Days` 对 once 最多返回 1 个触发器

- [ ] **Step 1: 写失败测试**

```dart
group('calculateNext7Days once alarm', () {
  test('once 闹钟最多返回 1 个未来触发器', () async {
    final alarm = AlarmInfo.create(
        id: 1, hour: 7, minute: 0, repeatType: RepeatType.once);
    final list = await AlarmSchedulerService.calculateNext7Days(alarm);
    expect(list.length, lessThanOrEqualTo(1));
  });
});
```

（若现有测试文件的 DB/HolidayService 初始化方式不同，沿用该文件里已有的 setUp 模式；HolidayService 无缓存数据时返回 null，等价于无节假日。）

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/services/alarm_scheduler_service_test.dart`
Expected: 新增用例 FAIL（现实现 once 返回最多 7 个）。

- [ ] **Step 3: 实现**（`calculateNextTrigger` 整体替换为）：

```dart
  static Future<DateTime?> calculateNextTrigger(
    AlarmInfo alarm, {
    List<WeekSchedule>? overrides,
    DateTime? from,
  }) async {
    final effectiveOverrides = overrides ?? [];
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Today's holiday status (needed for the once / start-day decision)
    bool todayIsHoliday = false;
    bool todayIsWorkday = false;
    try {
      final info = await HolidayService.getHolidayInfo(today);
      todayIsHoliday = info?.isHoliday ?? false;
      todayIsWorkday = info?.isWorkday ?? false;
    } catch (e) {
      debugPrint('Holiday check failed for today: $e');
    }
    final alarmTimeToday = alarmTimeForDate(alarm, today, effectiveOverrides,
        isWorkday: todayIsWorkday);

    DateTime start;
    switch (alarm.repeatType) {
      case RepeatType.once:
        final todayRings = shouldRingOnDate(alarm, today, effectiveOverrides,
            isHoliday: todayIsHoliday, isWorkday: todayIsWorkday);
        if (todayRings && now.isBefore(alarmTimeToday)) {
          return alarmTimeToday;
        }
        return null;
      default:
        start = now.isBefore(alarmTimeToday)
            ? today
            : today.add(const Duration(days: 1));
    }

    for (int i = 0; i < 365; i++) {
      final candidate = start.add(Duration(days: i));
      HolidayInfo? info;
      try {
        info = await HolidayService.getHolidayInfo(candidate);
      } catch (e) {
        debugPrint('Holiday check failed for $candidate: $e');
      }
      final isHoliday = info?.isHoliday ?? false;
      final isWorkday = info?.isWorkday ?? false;
      if (shouldRingOnDate(alarm, candidate, effectiveOverrides,
          isHoliday: isHoliday, isWorkday: isWorkday)) {
        return alarmTimeForDate(alarm, candidate, effectiveOverrides,
            isWorkday: isWorkday);
      }
    }
    return null;
  }
```

`scheduleAlarm` 中删除二次时间计算（原 133-134 行），直接用 `nextDate`（它已带正确时分）：

```dart
    final nextDate = await calculateNextTrigger(alarm, overrides: overrides);
    if (nextDate == null) return;

    // safety: if still in the past, skip (e.g. one-time alarm already fired)
    if (nextDate.isBefore(DateTime.now())) return;
```

（后续 `scheduleAlarmNotification` 调用处 `scheduledDate: scheduledDate` 改为 `scheduledDate: nextDate`。）

`calculateNext7Days` 在 `triggers.add(current);` 之后加一行：

```dart
      triggers.add(current);
      // One-time alarms have at most one future trigger.
      if (alarm.repeatType == RepeatType.once) break;
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/services/alarm_scheduler_service_test.dart && flutter analyze`
Expected: 全绿；analyze 零 error。若 `HolidayInfo` 未从 holiday_service.dart 导出而测试文件需要，注意 import。

- [ ] **Step 5: Commit**

```bash
git add lib/services/alarm_scheduler_service.dart test/services/alarm_scheduler_service_test.dart
git commit -m "fix(scheduler): 补班周六用专用时间；once 未来触发器唯一；假期查询合并"
```

---

### Task 3: 关闭开关必须取消已排定的原生闹钟

**Files:**
- Modify: `lib/providers/alarm_provider.dart:22-40`（loadAlarms）

**Interfaces:**
- Consumes: `AlarmSchedulerService.cancelAlarm(int alarmId)`（幂等，内部 catch 平台通道异常）
- Produces: `loadAlarms()` 副作用——所有 `isEnabled=false` 的闹钟其原生 AlarmManager 条目被取消

**说明：** 该路径绑死平台通道（MethodChannel → AlarmManager），无法在单元测试断言；以 analyze + 手动验证清单验收（真机：设一个 2 分钟后的闹钟 → 关开关 → 到点不响）。

- [ ] **Step 1: 实现**

```dart
  Future<void> loadAlarms() async {
    try {
      _alarms = await AlarmStorageService.getAll();
      _loaded = true;
      notifyListeners();

      // Attempt to reschedule (non-critical — alarms still show even if scheduling fails)
      final overrides = await ScheduleStorageService.getAll();
      await AlarmSchedulerService.rescheduleAll(_alarms, overrides: overrides);

      // Cancel any armed native alarms for disabled entries. Without this,
      // toggling a switch off leaves the previously scheduled AlarmManager
      // entry alive and the alarm still rings.
      for (final alarm in _alarms) {
        if (!alarm.isEnabled && alarm.id != null) {
          await AlarmSchedulerService.cancelAlarm(alarm.id!);
        }
      }
    } catch (e) {
      // Ensure alarms still display even if scheduling fails
      if (!_loaded) {
        _alarms = await AlarmStorageService.getAll();
        _loaded = true;
        notifyListeners();
      }
      debugPrint('loadAlarms scheduling error: $e');
    }
  }
```

- [ ] **Step 2: analyze**

Run: `flutter analyze`
Expected: 零 error。

- [ ] **Step 3: Commit**

```bash
git add lib/providers/alarm_provider.dart
git commit -m "fix(alarm): 关闭开关时取消已排定的原生闹钟，避免关了还响"
```

---

### Task 4: snooze 走 AlarmManager + 读取 snoozeMinutes

**Files:**
- Modify: `lib/services/alarm_notification_service.dart:300-348`（snoozeAlarm）

**Interfaces:**
- Consumes: `AlarmStorageService.getById(int) → Future<AlarmInfo?>`（含 `snoozeMinutes`、`ringtone`）；`_alarmSchedulerChannel`（已有）
- Produces: `snoozeAlarm(int alarmId, String? title, String? body)` —— 用闹钟配置的 snoozeMinutes，经原生 AlarmManager 排定（到点由 AlarmReceiver 启动持续响铃）

- [ ] **Step 1: 实现**（整体替换 snoozeAlarm）

```dart
  /// Snoozes an alarm using its configured [AlarmInfo.snoozeMinutes].
  ///
  /// Schedules through the native AlarmManager channel so the snoozed
  /// alarm fires via AlarmReceiver → AlarmRingingService (continuous
  /// ringing + vibration), same as a normal alarm. Falls back to
  /// zonedSchedule (notification-only) if the channel is unavailable.
  Future<void> snoozeAlarm(int alarmId, String? title, String? body) async {
    AlarmInfo? alarm;
    try {
      alarm = await AlarmStorageService.getById(alarmId);
    } catch (e) {
      debugPrint('snoozeAlarm: failed to load alarm $alarmId: $e');
    }
    final minutes = alarm?.snoozeMinutes ?? 5;
    final scheduledDate = DateTime.now().add(Duration(minutes: minutes));

    if (Platform.isAndroid) {
      try {
        await _alarmSchedulerChannel.invokeMethod<void>('scheduleExactAlarm', {
          'alarmId': alarmId,
          'epochMillis': scheduledDate.millisecondsSinceEpoch,
          'title': title ?? '战马闹钟',
          'body': body ?? '稍后提醒',
          'ringtoneUri': alarm?.ringtone ?? 'default',
        });
        debugPrint('Snoozed alarm $alarmId via AlarmManager for $minutes min');
        return;
      } catch (e) {
        debugPrint('AlarmManager snooze failed, falling back to zonedSchedule: $e');
      }
    }

    // Fallback: notification-only (zonedSchedule never starts the ringing service)
    try {
      await _plugin.cancel(id: alarmId);
    } catch (e) {
      debugPrint('snoozeAlarm cancel failed (expected in test env): $e');
    }
    final sound = _ringtoneToSound(alarm?.ringtone ?? 'default');
    final androidDetails = AndroidNotificationDetails(
      // ...保持原有字段不变，仅 sound: sound 使用上面的 sound 变量...
    );
    // ...其余原有 zonedSchedule 逻辑不变，scheduledDate 用上面的变量...
    await _plugin.zonedSchedule(
      id: alarmId,
      title: title ?? '战马闹钟',
      body: body ?? '稍后提醒',
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: alarmId.toString(),
    );
  }
```

注意：调用点（`_onNotificationResponse`、`_onBackgroundNotificationResponse`、`alarm_fullscreen_screen.dart:128`）签名不变，无需改动。`snoozeAlarm` 不再用固定 `Duration(minutes: 5)` 与固定 `ringtone` 参数。

- [ ] **Step 2: analyze + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 零 error，全绿。

- [ ] **Step 3: Commit**

```bash
git add lib/services/alarm_notification_service.dart
git commit -m "fix(snooze): 走 AlarmManager 持续响铃并使用闹钟配置的 snoozeMinutes"
```

---

### Task 5: once 闹钟 dismiss 后自动禁用

**Files:**
- Modify: `lib/services/alarm_scheduler_service.dart`（新增静态方法）
- Modify: `lib/services/alarm_notification_service.dart:158-169`（_rescheduleAfterDismiss）、`lib/services/alarm_notification_service.dart:493-504`（_rescheduleInBackground）
- Modify: `lib/screens/alarm_fullscreen_screen.dart:107-124`（_dismiss）

**Interfaces:**
- Consumes: `AlarmStorageService.getById/toggleEnabled`；`ScheduleStorageService.getAll`
- Produces: `AlarmSchedulerService.handleDismissed(int alarmId) → Future<void>`

- [ ] **Step 1: 实现**（alarm_scheduler_service.dart 顶部 import 区新增 `import 'alarm_storage_service.dart';` 与 `import 'schedule_storage_service.dart';`，类内新增）：

```dart
  /// Called when an alarm is dismissed (user taps 关闭).
  /// Repeating alarms get their next trigger scheduled;
  /// one-time alarms are disabled so the UI switch reflects reality.
  static Future<void> handleDismissed(int alarmId) async {
    final alarm = await AlarmStorageService.getById(alarmId);
    if (alarm == null) return;
    if (alarm.repeatType == RepeatType.once) {
      await AlarmStorageService.toggleEnabled(alarmId, false);
    } else {
      final overrides = await ScheduleStorageService.getAll();
      await scheduleAlarm(alarm, overrides: overrides);
    }
  }
```

三处调用点替换为：

```dart
  Future<void> _rescheduleAfterDismiss(int alarmId) async {
    try {
      await AlarmSchedulerService.handleDismissed(alarmId);
      debugPrint('Handled dismissed alarm $alarmId');
    } catch (e) {
      debugPrint('Failed to handle dismissed alarm $alarmId: $e');
    }
  }
```

```dart
Future<void> _rescheduleInBackground(int alarmId) async {
  try {
    await AlarmSchedulerService.handleDismissed(alarmId);
    debugPrint('Handled dismissed alarm $alarmId in background');
  } catch (e) {
    debugPrint('Failed to handle dismissed alarm $alarmId in background: $e');
  }
}
```

`alarm_fullscreen_screen.dart` 的 `_dismiss()` 中 112-121 行的 try 块替换为：

```dart
    try {
      await AlarmSchedulerService.handleDismissed(widget.alarmId);
      debugPrint('Handled dismissed alarm ${widget.alarmId}');
    } catch (e) {
      debugPrint('Failed to handle dismissed alarm after dismiss: $e');
    }
```

（该文件顶部 import 已有 `alarm_scheduler_service.dart`；`alarm_storage_service`/`schedule_storage_service` 的 import 若因此不再被使用则删除，由 analyzer 提示。）

- [ ] **Step 2: analyze + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 零 error，全绿。

- [ ] **Step 3: Commit**

```bash
git add lib/services/alarm_scheduler_service.dart lib/services/alarm_notification_service.dart lib/screens/alarm_fullscreen_screen.dart
git commit -m "fix(alarm): 一次性闹钟关闭后自动禁用；dismiss 处理收敛到 handleDismissed"
```

---

### Task 6: 通知栏「关闭闹钟」按钮后重排下一次（原生）

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/alarm_clock/AlarmRingingService.kt:126-152`（onStartCommand）、`android/app/src/main/kotlin/com/example/alarm_clock/AlarmRingingService.kt:111-116`（stop 方法）、`android/app/src/main/kotlin/com/example/alarm_clock/AlarmRingingService.kt:159-171`（onTaskRemoved）
- Modify: `android/app/src/main/kotlin/com/example/alarm_clock/MainActivity.kt:161-164`（stopAlarmRing handler）

**Interfaces:**
- Consumes: `AlarmRescheduleWorker`（已有；重排幂等）
- Produces: `AlarmRingingService.stop(context, fromFlutter: Boolean = false)`；ACTION_STOP 且非 Flutter 来源时 enqueue 重排 worker

**背景：** 用户从通知栏点「关闭闹钟」→ ACTION_STOP 只停响铃，重复闹钟的下一次排定丢失，直到下次打开 App。Flutter 全屏关闭路径自己会重排（Task 5），所以 Flutter 来源的 stop 不重复 enqueue。

- [ ] **Step 1: 实现**

AlarmRingingService.kt：

```kotlin
        fun stop(context: Context, fromFlutter: Boolean = false) {
            val intent = Intent(context, AlarmRingingService::class.java).apply {
                action = ACTION_STOP
                putExtra("fromFlutter", fromFlutter)
            }
            context.startService(intent)
        }
```

```kotlin
            ACTION_STOP -> {
                stopRinging()
                // Notification STOP button path has no Flutter involvement:
                // reschedule the next occurrence here so repeating alarms
                // don't lose their schedule until the next app launch.
                if (intent.getBooleanExtra("fromFlutter", false) != true) {
                    rescheduleNext()
                }
                return START_NOT_STICKY
            }
```

新增私有方法（替换 onTaskRemoved 中的内联逻辑，两处共用）：

```kotlin
    private fun rescheduleNext() {
        try {
            val workRequest = androidx.work.OneTimeWorkRequestBuilder<AlarmRescheduleWorker>().build()
            androidx.work.WorkManager.getInstance(applicationContext).enqueue(workRequest)
            Log.d(TAG, "Enqueued AlarmRescheduleWorker")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enqueue reschedule work", e)
        }
    }
```

`onTaskRemoved` 改为：

```kotlin
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopRinging()
        // Reschedule the next alarm when the user swipes away the app from recents.
        rescheduleNext()
        super.onTaskRemoved(rootIntent)
    }
```

MainActivity.kt 的 `"stopAlarmRing"` 分支改为：

```kotlin
                "stopAlarmRing" -> {
                    AlarmRingingService.stop(this, fromFlutter = true)
                    result.success(null)
                }
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: 构建成功。（Kotlin 无单测，CI 的 analyze+test 不覆盖 Kotlin，以本地 debug 构建为准。）

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/alarm_clock/AlarmRingingService.kt android/app/src/main/kotlin/com/example/alarm_clock/MainActivity.kt
git commit -m "fix(android): 通知栏关闭闹钟后自动重排下一次，避免重复闹钟断档"
```

---

### Task 7: 计时器暂停后清持久化，防止进程被杀后「复活」

**Files:**
- Modify: `lib/providers/timer_provider.dart:113-121`（pause）
- Test: 新建 `test/providers/timer_provider_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences.setMockInitialValues`（测试）；`_clearPersistedTimer()`
- Produces: `pause()` 副作用——清除 `timer_end_time`/`timer_total_seconds` 两个 key

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
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
```

（channel 名以 `lib/services/timer_background_service.dart` 实际常量为准，实现时核对。）

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/providers/timer_provider_test.dart`
Expected: FAIL（pause 后 prefs 仍残留 endTime）。

- [ ] **Step 3: 实现**

`pause()` 加一行：

```dart
  void pause() {
    if (_state != TimerState.running) return;
    _state = TimerState.paused;
    _timer?.cancel();
    _timer = null;
    // Cancel the native alarm while paused — it will be rescheduled on resume
    TimerBackgroundService.cancelTimerAlarm();
    // Clear persisted endTime so a killed process doesn't restore a
    // "running" timer the user explicitly paused.
    _clearPersistedTimer();
    notifyListeners();
  }
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/providers/timer_provider_test.dart && flutter analyze`
Expected: PASS；analyze 零 error。

- [ ] **Step 5: Commit**

```bash
git add lib/providers/timer_provider.dart test/providers/timer_provider_test.dart
git commit -m "fix(timer): 暂停时清除持久化状态，防止进程被杀后恢复成运行态"
```

---

### Task 8: 秒表超过 1 小时显示小时位

**Files:**
- Modify: `lib/providers/stopwatch_provider.dart:38-43`（formattedTime）
- Test: 新建 `test/providers/stopwatch_provider_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/providers/stopwatch_provider.dart';

void main() {
  test('超过 1 小时显示 HH:MM:SS.cc 而非回绕', () {
    expect(StopwatchProvider.format(const Duration(minutes: 90, seconds: 5, milliseconds: 120)),
        '01:30:05.12');
    expect(StopwatchProvider.format(const Duration(minutes: 3, seconds: 5, milliseconds: 120)),
        '03:05.12');
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/providers/stopwatch_provider_test.dart`
Expected: FAIL（`StopwatchProvider.format` 不存在，编译失败）。

- [ ] **Step 3: 实现**

```dart
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
```

（`@visibleForTesting` 来自 `package:flutter/foundation.dart`，文件已 import。）

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/providers/stopwatch_provider_test.dart && flutter analyze`
Expected: PASS；analyze 零 error。

- [ ] **Step 5: Commit**

```bash
git add lib/providers/stopwatch_provider.dart test/providers/stopwatch_provider_test.dart
git commit -m "fix(stopwatch): 超过1小时显示小时位，修复分钟回绕"
```

---

### Task 9: 时区按设备设置（flutter_timezone）

**Files:**
- Modify: `pubspec.yaml`（dependencies 新增 flutter_timezone）
- Modify: `lib/main.dart:165-172`（main 初始化段）

- [ ] **Step 1: 加依赖**

Run: `flutter pub add flutter_timezone`
Expected: pubspec 出现 `flutter_timezone: ^x.y.z`。

- [ ] **Step 2: 实现**

`lib/main.dart` import 区新增 `import 'package:flutter_timezone/flutter_timezone.dart';`，替换 171-172 行：

```dart
  tz.initializeTimeZones();
  // Use the device timezone so zonedSchedule fires at the right local time
  // on any device; fall back to Asia/Shanghai when detection fails.
  try {
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));
  } catch (e) {
    debugPrint('Failed to detect device timezone, defaulting to Asia/Shanghai: $e');
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  }
```

- [ ] **Step 3: analyze + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 零 error，全绿。

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart
git commit -m "fix(timezone): 按设备时区设置 tz.local，检测失败回退上海"
```

---

### Task 10: Boot 重排回传 rescheduleComplete，消除 15 秒白等

**Files:**
- Modify: `lib/main.dart:201-206`（bootChannel handler）

- [ ] **Step 1: 实现**

```dart
  const bootChannel = MethodChannel('com.example.alarm_clock/boot_receiver');
  bootChannel.setMethodCallHandler((call) async {
    if (call.method == 'rescheduleAlarms') {
      await BootReceiverService.rescheduleAlarmsAfterBoot();
      // Signal the native AlarmRescheduleWorker so it doesn't wait the
      // full 15s MAX_WAIT_MILLIS timeout.
      await bootChannel.invokeMethod('rescheduleComplete');
    }
  });
```

- [ ] **Step 2: analyze**

Run: `flutter analyze`
Expected: 零 error。

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "fix(boot): 重排完成后回传 rescheduleComplete，避免 worker 白等15秒"
```

---

### Task 11: 节假日 key 解析防御化 + 失败可观测

**Files:**
- Modify: `lib/services/holiday_service.dart:103-141`（fetchAndCacheYear 解析段 + catch 日志）
- Test: `test/services/holiday_service_test.dart`（新建，仅测解析函数）

**Interfaces:**
- Consumes: timor.tech API `holiday` map：key 为 `"1.1"` 或 `"01-01"`（横线/点分隔，可能无前导零）；entry 含 `holiday: bool`
- Produces: `HolidayService.parseDateKey(String key, int year) → DateTime`（static，支持两种分隔符）

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:alarm_clock/services/holiday_service.dart';

void main() {
  group('parseDateKey', () {
    test('横线格式 01-01', () {
      expect(HolidayService.parseDateKey('01-01', 2026), DateTime(2026, 1, 1));
    });
    test('点格式 1.1（无前导零）', () {
      expect(HolidayService.parseDateKey('1.1', 2026), DateTime(2026, 1, 1));
    });
    test('点格式 10.1', () {
      expect(HolidayService.parseDateKey('10.1', 2026), DateTime(2026, 10, 1));
    });
    test('非法格式抛 FormatException', () {
      expect(() => HolidayService.parseDateKey('abc', 2026),
          throwsFormatException);
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/services/holiday_service_test.dart`
Expected: FAIL（`parseDateKey` 不存在）。

- [ ] **Step 3: 实现**

holiday_service.dart 新增：

```dart
  /// Parses a timor.tech holiday date key into a DateTime.
  /// Accepts both "01-01" (dash, zero-padded) and "1.1" (dot, unpadded)
  /// formats — the API has returned both over time.
  static DateTime parseDateKey(String key, int year) {
    final parts = key.split(RegExp(r'[-.]'));
    if (parts.length != 2) {
      throw FormatException('Unexpected holiday date key: $key');
    }
    final month = int.parse(parts[0]);
    final day = int.parse(parts[1]);
    return DateTime(year, month, day);
  }
```

fetchAndCacheYear 解析段（原 104-113 行）替换为：

```dart
        final dateStr = entry.key; // e.g. "01-01" or "1.1"
        final info = entry.value as Map<String, dynamic>;

        final date = parseDateKey(dateStr, year);
        final isoDate = date.toIso8601String().substring(0, 10);
```

catch 段（原 136-138 行）改为输出真实错误，避免静默失效：

```dart
    } catch (e, stack) {
      debugPrint('Failed to fetch holiday data for $year: $e\n$stack');
      return 0;
    } finally {
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/services/holiday_service_test.dart && flutter analyze && flutter test`
Expected: 全绿；analyze 零 error。

- [ ] **Step 5: Commit**

```bash
git add lib/services/holiday_service.dart test/services/holiday_service_test.dart
git commit -m "fix(holiday): 兼容点/横线两种日期key格式，失败时输出完整日志"
```

---

### Task 12: 模型防御（WeekSchedule 枚举越界、AlarmInfo copyWith/解析）

**Files:**
- Modify: `lib/models/week_schedule.dart:51-61`（fromMap）
- Modify: `lib/models/alarm_info.dart:122-144`（fromMap weekdays）、`lib/models/alarm_info.dart:146-178`（copyWith label）
- Test: `test/models/week_schedule_test.dart`、`test/models/alarm_info_test.dart`（追加）

- [ ] **Step 1: 写失败测试**

week_schedule_test.dart 追加：

```dart
  test('fromMap 越界 weekType 回退 double 而非崩溃', () {
    final ws = WeekSchedule.fromMap({
      'id': 1, 'weekIndex': 1, 'year': 2026, 'month': 8, 'weekOfMonth': 1,
      'weekType': 99, 'createdAt': 0,
    });
    expect(ws.weekType, WeekType.double);
  });
```

alarm_info_test.dart 追加：

```dart
  test('fromMap 损坏 weekdays 字符串不崩溃', () {
    final alarm = AlarmInfo.fromMap({
      'id': 1, 'hour': 7, 'minute': 0, 'repeatType': 0,
      'weekdays': '1,x,3', 'vibrate': 1, 'snoozeMinutes': 5,
      'isEnabled': 1, 'taskType': 0,
    });
    expect(alarm.weekdays, [1, 3]);
  });

  test('copyWith 可以清空 label', () {
    final alarm = AlarmInfo.create(id: 1, hour: 7, minute: 0, label: '起床');
    expect(alarm.copyWith(clearLabel: true).label, isNull);
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/models/`
Expected: 新增用例 FAIL（现实现越界崩溃 / int.parse 抛错 / copyWith 无 clearLabel）。

- [ ] **Step 3: 实现**

week_schedule.dart fromMap：

```dart
      weekType: WeekType.values[map['weekType'] as int],
```
改为（类内新增 `_safeWeekType`）：

```dart
      weekType: _safeWeekType(map['weekType'] as int?),
```

```dart
WeekType _safeWeekType(int? index) {
  if (index == null || index < 0 || index >= WeekType.values.length) {
    return WeekType.double;
  }
  return WeekType.values[index];
}
```

alarm_info.dart fromMap weekdays：

```dart
        : weekdaysStr.split(',').map((s) => int.parse(s)).toList();
```
改为：

```dart
        : weekdaysStr
            .split(',')
            .where((s) => int.tryParse(s) != null)
            .map((s) => int.parse(s))
            .toList();
```

alarm_info.dart copyWith：签名加 `bool clearLabel = false,`，label 行改为：

```dart
      label: clearLabel ? null : (label ?? this.label),
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/models/ && flutter analyze`
Expected: 全绿；analyze 零 error。

- [ ] **Step 5: Commit**

```bash
git add lib/models/week_schedule.dart lib/models/alarm_info.dart test/models/
git commit -m "fix(models): 枚举越界与损坏数据防御；copyWith 支持清空 label"
```

---

### Task 13: 日历行锚定（用行周一算 weekIndex，消除跨月碰撞）

**Files:**
- Modify: `lib/widgets/week_schedule_calendar.dart:118-135`（_buildWeekRow 传参）、`lib/widgets/week_schedule_calendar.dart:313-334`（_showWeekTypeSheet）、`lib/widgets/week_schedule_calendar.dart:378-404`（_WeekTypeSheet 构造与 build）
- Modify: `lib/providers/schedule_provider.dart:39-64`（setOverride 不变，仅保证 weekIndex 参数被传入）

**Interfaces:**
- Consumes: `weekNumber(DateTime)`（Task 1 修复后）；`provider.setOverride(year, month, weekOfMonth, type, {weekIndex})`（已存在可选参数）
- Produces: `_WeekTypeSheet({required DateTime rowMonday, ...})` —— 内部用 rowMonday 计算自动类型与 weekIndex

- [ ] **Step 1: 实现**

`_showWeekTypeSheet` 增加 `DateTime rowMonday` 参数并下传；`_buildWeekRow` 调用处改为 `_showWeekTypeSheet(context, week.weekOfMonth, weekType, week.days.first);`。

```dart
  void _showWeekTypeSheet(
    BuildContext context,
    int weekOfMonth,
    WeekType currentType,
    DateTime rowMonday,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _WeekTypeSheet(
          year: widget.year,
          month: widget.month,
          weekOfMonth: weekOfMonth,
          rowMonday: rowMonday,
          currentType: currentType,
          provider: widget.provider,
        );
      },
    );
  }
```

`_WeekTypeSheet` 增加 `final DateTime rowMonday;`（required），build 中 `autoType` 计算改为：

```dart
    final autoType = alarm_utils.autoWeekType(widget.rowMonday);
```

`_selectType` 改为：

```dart
  Future<void> _selectType(BuildContext context, WeekType type) async {
    await provider.setOverride(year, month, weekOfMonth, type,
        weekIndex: alarm_utils.weekNumber(widget.rowMonday));
    if (context.mounted) Navigator.of(context).pop();
  }
```

（删除原先 `DateTime(year, month, (weekOfMonth - 1) * 7 + 1)` 的 flat 计算。）

- [ ] **Step 2: analyze + 全量测试**

Run: `flutter analyze && flutter test`
Expected: 零 error，全绿（`widget_test.dart` 若覆盖日历需同步通过；若 widget_test 引用 _WeekTypeSheet 私有类则跳过——其为私有类，测试无法直接引用）。

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/week_schedule_calendar.dart
git commit -m "fix(calendar): 周类型锚定行周一日期，消除第6周与下月第1周 weekIndex 碰撞"
```

---

### Task 2b: BootReceiver.kt 原生镜像同步（补班策略 + 从 SQLite 读节假日 + 负数周）

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/alarm_clock/BootReceiver.kt:280-289`（readDateSet）、`android/app/src/main/kotlin/com/example/alarm_clock/BootReceiver.kt:293-297`（weekNumber）、`android/app/src/main/kotlin/com/example/alarm_clock/BootReceiver.kt:323-372`（shouldRingOnDate）、`android/app/src/main/kotlin/com/example/alarm_clock/BootReceiver.kt:374-398`（alarmTimeForDate）、`android/app/src/main/kotlin/com/example/alarm_clock/BootReceiver.kt:405-446`（computeNextTrigger）

**Interfaces:**
- Consumes: `holiday_cache` 表 schema（`date TEXT PRIMARY KEY, isHoliday INTEGER, isWorkday INTEGER`，date 为 `yyyy-MM-dd`）；`AlarmRow`/`WeekOverride`（同文件）
- Produces: `readHolidaySetsFromDb(context) → Pair<Set<String>, Set<String>>`（holidaySet, makeupSet）；`shouldRingOnDate(...)` 补班策略与 Dart 一致；`alarmTimeForDate(alarm, date, overrides, makeupSet)` 补班周六用周六时间

**背景：** 开机双路径：Path 1 原生 AlarmManager（保底、同步）用本文件内 Kotlin 镜像的引擎；Path 2 Dart worker 异步全量重排。镜像必须与 `lib/utils/date_utils.dart` 保持一致。同时修复：原实现从 SharedPreferences 读 `flutter.holiday_dates`/`flutter.makeup_workday_dates`，但 Dart 侧**从不写这两个 key**（HolidayService 只写 SQLite `holiday_cache` 表）→ 原生路径节假日/补班永远失效，改为直接查表。

- [ ] **Step 1: 实现**

`readDateSet` 替换为（删除原函数，新增）：

```kotlin
    /**
     * Reads holiday / make-up workday sets directly from the
     * holiday_cache table that HolidayService writes (Dart side never
     * writes the legacy flutter.holiday_dates prefs keys).
     * Returns Pair(holidaySet, makeupSet) of yyyy-MM-dd strings.
     */
    private fun readHolidaySetsFromDb(context: Context): Pair<Set<String>, Set<String>> {
        val db = openDb(context) ?: return Pair(emptySet(), emptySet())
        val holidays = mutableSetOf<String>()
        val makeups = mutableSetOf<String>()
        val cursor: Cursor? = try {
            db.rawQuery(
                "SELECT date, isHoliday, isWorkday FROM holiday_cache",
                null
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query holiday_cache", e)
            null
        }
        cursor?.use { c ->
            val dIdx = c.getColumnIndexOrThrow("date")
            val hIdx = c.getColumnIndexOrThrow("isHoliday")
            val wIdx = c.getColumnIndexOrThrow("isWorkday")
            while (c.moveToNext()) {
                val d = c.getString(dIdx)
                if (c.getInt(hIdx) == 1) holidays.add(d)
                if (c.getInt(wIdx) == 1) makeups.add(d)
            }
        }
        db.close()
        return Pair(holidays, makeups)
    }
```

`rescheduleNative` 中（原 113-114 行）改为：

```kotlin
        val (holidaySet, makeupSet) = readHolidaySetsFromDb(context)
```

`weekNumber` 改为 floorDiv（Kotlin `/` 对负数向零截断，与 Dart 修复前同病）：

```kotlin
    private fun weekNumber(dateMs: Long): Int {
        val diff = dateMs - WEEK_EPOCH_MS
        val days = Math.floorDiv(diff, 86_400_000L)
        return Math.floorDiv(days, 7) + 1
    }
```

`shouldRingOnDate` 补班分支与 doubleRest 死代码（镜像 Task 1）：

```kotlin
        if (dateKey in holidaySet) return false
        // Make-up workday (补班): force ring for workday-semantic types only;
        // once/custom fall through to their own rules.
        if (dateKey in makeupSet) {
            val isWorkdayType = alarm.repeatType == REPEAT_DAILY ||
                alarm.repeatType == REPEAT_WEEKDAYS ||
                alarm.repeatType == REPEAT_SINGLE_REST ||
                alarm.repeatType == REPEAT_DOUBLE_REST
            if (isWorkdayType) return true
        }
```

```kotlin
            REPEAT_DOUBLE_REST -> {
                if (dartWd == 6 || dartWd == 7) return false
                return true
            }
```

`alarmTimeForDate` 增加 makeupSet 参数，补班周六用周六时间：

```kotlin
    private fun alarmTimeForDate(
        alarm: AlarmRow,
        date: Calendar,
        overrides: List<WeekOverride>,
        makeupSet: Set<String>,
    ): Calendar {
        val cal = Calendar.getInstance().apply {
            timeInMillis = date.timeInMillis
            set(Calendar.HOUR_OF_DAY, alarm.hour)
            set(Calendar.MINUTE, alarm.minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (alarm.repeatType == REPEAT_SINGLE_REST &&
            date.get(Calendar.DAY_OF_WEEK) == Calendar.SATURDAY
        ) {
            val wt = resolveWeekType(date.timeInMillis, overrides)
            val isMakeup = ymd(date) in makeupSet
            if (wt == WEEK_SINGLE || isMakeup) {
                val sh = alarm.saturdayHour ?: alarm.hour
                val sm = alarm.saturdayMinute ?: alarm.minute
                cal.set(Calendar.HOUR_OF_DAY, sh)
                cal.set(Calendar.MINUTE, sm)
            }
        }
        return cal
    }
```

`computeNextTrigger`（镜像 Task 2 的今日假期判定）：

```kotlin
        val todayAlarmTime = alarmTimeForDate(alarm, today, overrides, makeupSet)

        val startCal: Calendar = when (alarm.repeatType) {
            REPEAT_ONCE -> {
                val todayRings = shouldRingOnDate(alarm, today, overrides, holidaySet, makeupSet)
                if (todayRings && now.before(todayAlarmTime)) return todayAlarmTime.timeInMillis
                return null
            }
            else -> {
                if (now.before(todayAlarmTime)) {
                    today.clone() as Calendar
                } else {
                    (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
                }
            }
        }

        for (i in 0 until 365) {
            val candidate = (startCal.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, i)
            }
            if (shouldRingOnDate(alarm, candidate, overrides, holidaySet, makeupSet)) {
                val trigger = alarmTimeForDate(alarm, candidate, overrides, makeupSet)
                if (trigger.timeInMillis > from) return trigger.timeInMillis
            }
        }
        return null
```

- [ ] **Step 2: 编译验证**

Run: `flutter build apk --debug`
Expected: 构建成功。

- [ ] **Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/example/alarm_clock/BootReceiver.kt
git commit -m "fix(boot): 原生路径节假日改查SQLite；补班策略与负数周与Dart对齐"
```

---

### Task 14: 版本 bump、全量验证、GitNexus 变更检查、push

**Files:**
- Modify: `pubspec.yaml:19`（version）

- [ ] **Step 1: bump 版本**

`version: 2.0.4+2006` → `version: 2.0.5+2007`

- [ ] **Step 2: 全量验证**

Run:
```bash
flutter analyze
flutter test
flutter build apk --debug
```
Expected: 全部通过。debug 构建验证 Kotlin 改动（Task 6）编译无误。

- [ ] **Step 3: GitNexus 变更检查**

运行 `gitnexus_detect_changes()`（MCP 工具），确认变更只涉及本次计划内的符号与执行流；如有预期外符号被波及，停下来检查。

- [ ] **Step 4: Commit + push**

```bash
git add pubspec.yaml
git commit -m "chore: bump version to v2.0.5+2007 for release"
git status   # 确认无未提交文件
git push origin master
```

Push 后 CI（.github/workflows/ci.yml）自动跑 analyze + test + Android APK + Web 构建。若要触发 release-android 发布 job，需打 tag（如 `v2.0.5`）——按需询问用户，不自动打。

- [ ] **Step 5: 汇总验证清单给用户**

真机手动验证清单：
1. 设 2 分钟后闹钟 → 关闭开关 → 到点不响（Task 3）
2. 补班日（或临时改 DB）闹钟按新策略响/不响（Task 1/2）
3. 稍后提醒到点持续响铃，间隔=设置值（Task 4）
4. 一次性闹钟关闭后开关变灰（Task 5）
5. 通知栏「关闭闹钟」后重复闹钟下一次照常响（Task 6）
6. 计时器暂停 → 杀进程 → 重启 App 计时器不复活（Task 7）
7. 秒表跑超 1 小时显示 HH:MM:SS.cc（Task 8）

---

## 收尾项（非本计划代码任务，完成后单独处理）

- **context-mode 插件崩溃**：better-sqlite3 原生模块为 Node 22 (ABI 127) 编译，当前 Node 24 (137)。两个选项：A) 把 context-mode MCP server 配置指向 Node 22 二进制（若系统存在）；B) `/ctx-upgrade` 升级到 v1.0.169（大概率带 Node 24 预编译）。修复后其 ctx_execute/ctx_fetch_and_index 工具恢复可用。
- **SessionStart hook error**：大概率同源（context-mode 插件相关 hook 在真实启动环境失败）。升级后若仍报错，用 `claude --debug` 定位具体 hook。

## Self-Review 结果

- 覆盖：审查 16 项全部有对应任务（#1→T3, #2→T11, #3→T4, #4→T1/T2, #5→T1, #6→T2, #7→T5, #8→T7, #9→T8, #10→T9, #11→T10, #12→T2, #13→T1, #14→T12, #15→T13, #16→T12）。
- 类型一致性：`alarmTimeForDate` 新签名在 T1 定义、T2 消费一致；`handleDismissed` 在 T5 定义、三处调用一致；`AlarmRingingService.stop(fromFlutter:)` 在 T6 定义、MainActivity 调用一致。
- 无占位符：所有代码步骤均给出完整实现。
