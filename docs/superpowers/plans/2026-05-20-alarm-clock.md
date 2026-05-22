# Alarm Clock 闹钟 App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter alarm clock app that supports 单双休 (alternating single/double rest weekend) scheduling, plus timer, stopwatch, and full schedule management with per-week override.

**Architecture:** Provider-based state management with sqflite for persistence. flutter_local_notifications handles alarm triggering in the background. A dedicated `AlarmSchedulerService` encapsulates the 单双休 week parity logic. Five-tab bottom navigation: 闹钟, 日程, 计时, 秒表, 设置.

**Tech Stack:** Flutter 3.35, Dart 3.9, Provider, sqflite, flutter_local_notifications, intl

---

## Design System (from prototype)

| Token | Value |
|---|---|
| Background | `#FDF8F3` (warm white) |
| Surface | `#FFFFFF` with 0.7 opacity + blur (glass cards) |
| Primary accent | `#E8936A` (sunrise peach) |
| Secondary accent | `#FAD0B4` (soft sunrise) |
| Gradient | `linear-gradient(180deg, #FAD0B4 0%, #FCE6D2 100%)` |
| Text primary | `#3D2C2A` (warm brown-black) |
| Text secondary | `#9A8A87` (muted warm gray) |
| Danger | `#E85A5A` (for delete/ringing) |
| Success/week off | `#6BBF8A` (green for 双休 indicators) |
| Radius | 20px (cards), 12px (small elements) |
| Page margin | 24px horizontal |
| Typography | Noto Sans SC (preferred), system fallback |
| Shadow | `0 4px 20px rgba(0,0,0,0.06)` (card) |
| Transition | `cubic-bezier(0.4, 0, 0.2, 1)` |

**AppBar style:** Transparent background, no elevation, back button and actions use primary accent color.

**Bottom nav:** White background with top border radius 20dp, selected item uses primary accent, unselected uses text secondary.

---

## File Structure

```
alarm_clock/lib/
├── main.dart                                  # Entry point, initialize services, BootReceiver
├── app.dart                                   # MaterialApp + theme (uses design system)
├── models/
│   ├── alarm_info.dart                        # AlarmInfo data model + RepeatType enum
│   └── week_schedule.dart                     # WeekSchedule model for per-week 单/双 overrides
├── providers/
│   ├── alarm_provider.dart                    # ChangeNotifier: alarm CRUD + scheduling
│   ├── timer_provider.dart                    # ChangeNotifier: countdown timer state
│   ├── stopwatch_provider.dart                # ChangeNotifier: stopwatch + laps
│   └── schedule_provider.dart                 # ChangeNotifier: week schedule overrides
├── services/
│   ├── alarm_storage_service.dart             # sqflite CRUD for alarms
│   ├── schedule_storage_service.dart          # sqflite CRUD for week schedule overrides
│   ├── alarm_notification_service.dart        # flutter_local_notifications init + show/cancel
│   └── alarm_scheduler_service.dart           # 单双休 logic + next-alarm calculation
├── screens/
│   ├── home_screen.dart                       # Scaffold with BottomNavigationBar (5 tabs)
│   ├── alarm_list_screen.dart                 # Tab 1: list of alarms + FAB
│   ├── add_edit_alarm_screen.dart             # Create/edit form with repeat type picker
│   ├── alarm_ringing_screen.dart              # Full-screen overlay when alarm fires
│   ├── schedule_screen.dart                   # Tab 2: monthly calendar with week-type toggle
│   ├── timer_screen.dart                      # Tab 3: countdown timer with presets
│   ├── stopwatch_screen.dart                  # Tab 4: stopwatch with lap tracking
│   └── settings_screen.dart                   # Tab 5: week type toggle, ringtone, about
├── widgets/
│   ├── alarm_tile.dart                        # Card for one alarm (time, label, repeat, switch)
│   ├── repeat_picker.dart                     # Repeat type chip selector
│   ├── week_schedule_calendar.dart            # Monthly calendar with per-week 单/双 toggle
│   ├── timer_picker.dart                      # Scroll wheel time picker for timer
│   └── timer_presets.dart                     # Quick preset chips (1min/3min/5min/10min)
└── utils/
    └── date_utils.dart                       # Week parity, day label, schedule resolution
```

---

## 单双休 Schedule Engine

### Core Logic (in utils/date_utils.dart)

- **Week parity:** Calculate week number since a known epoch (e.g., Jan 1, 2024 → week 1). Even/odd determines A/B pattern.
- **Auto mode:** Alternates every week. Single-rest (单休) = Saturday rings, Sunday off. Double-rest (双休) = Saturday off, Sunday off.
- **Override:** Per-week manual override stored in `week_schedule` table. Override takes priority over auto mode.
- **Resolution:** `resolveWeekType(date)` → checks override first, falls back to auto parity.
- **Current toggle:** Settings page allows toggling "current month starts as 单周 or 双周" which shifts the parity reference.

### Schedule Override Model

```dart
class WeekSchedule {
  final int? id;
  final int year;
  final int month;
  final int weekOfMonth;     // 1-based week index within the month
  final WeekType weekType;   // single or double (manual override)
  final DateTime createdAt;

  Map<String, dynamic> toMap() => { ... };
  factory WeekSchedule.fromMap(Map<String, dynamic> map) => ...;
}

enum WeekType { single, double }
```

### Schedule Storage (services/schedule_storage_service.dart)

Separate sqflite table `week_schedules`:
```sql
CREATE TABLE week_schedules (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  year INTEGER NOT NULL,
  month INTEGER NOT NULL,
  week_of_month INTEGER NOT NULL,
  week_type INTEGER NOT NULL,  -- 0=单休, 1=双休
  created_at TEXT NOT NULL,
  UNIQUE(year, month, week_of_month)
);
```

---

## Task List

### Task 1: Project Setup & Dependencies

**Files:**
- Modify: `alarm_clock/pubspec.yaml`

- [ ] **Step 1: Add dependencies to pubspec.yaml**

Add these under `dependencies` alongside the existing flutter SDK:
- `provider: ^6.1.2`
- `sqflite: ^2.4.1`
- `path_provider: ^2.1.5`
- `intl: ^0.19.0`
- `flutter_local_notifications: ^18.0.1`

- [ ] **Step 2: Run `flutter pub get`**

Verify the Chinese pub mirror resolves correctly (pub.flutter-io.cn is already configured in pubspec.lock).

---

### Task 2: AlarmInfo Model

**Files:**
- Create: `lib/models/alarm_info.dart`

- [ ] **Step 1: Define RepeatType enum**

Values: `once`, `daily`, `weekdays`, `weekends`, `singleRest`, `doubleRest`, `custom`.

- [ ] **Step 2: Define AlarmInfo class**

Fields:
- `int? id` — auto-increment primary key
- `int hour`, `int minute` — alarm time
- `RepeatType repeatType` — recurrence pattern
- `List<int> weekdays` — custom weekday selection (1=Monday … 7=Sunday)
- `String? label` — optional alarm name
- `bool vibrate` — default true
- `int snoozeMinutes` — default 5
- `bool isEnabled` — default true
- `DateTime? singleRestReferenceDate` — reference date for singleRest parity (null = auto)

Include `toMap()` / `fromMap()` serialization for sqflite.

- [ ] **Step 3: Write model tests**

Create `test/models/alarm_info_test.dart`:
- Test AlarmInfo creation with default values
- Test toMap/fromMap round-trip
- Test all RepeatType values serialize correctly

---

### Task 3: WeekSchedule Model

**Files:**
- Create: `lib/models/week_schedule.dart`

- [ ] **Step 1: Define WeekType enum**

Values: `single`, `double`.

- [ ] **Step 2: Define WeekSchedule class**

Fields: `int? id`, `int year`, `int month`, `int weekOfMonth`, `WeekType weekType`, `DateTime createdAt`.

Include `toMap()` / `fromMap()` serialization.

- [ ] **Step 3: Write model tests**

Create `test/models/week_schedule_test.dart`:
- Test WeekSchedule creation
- Test toMap/fromMap round-trip
- Test unique constraint enforcement (year+month+weekOfMonth)

---

### Task 4: Date Utilities (单双休 Engine)

**Files:**
- Create: `lib/utils/date_utils.dart`

- [ ] **Step 1: Implement week parity calculation**

Functions:
- `int weekNumber(DateTime date)` — ISO week number since epoch
- `WeekType autoWeekType(DateTime date)` — even/odd parity
- `WeekType resolveWeekType(DateTime date, List<WeekSchedule> overrides)` — override-first, fallback to auto
- `bool shouldRingOnDate(AlarmInfo alarm, DateTime date, List<WeekSchedule> overrides)` — core function
- `DateTime? nextAlarmDate(AlarmInfo alarm, List<WeekSchedule> overrides)` — find next ring time
- `String weekTypeLabel(WeekType wt)` — "单休" / "双休"
- `String dayLabel(int weekday)` — "星期一" … "星期日"

- [ ] **Step 2: Write unit tests**

Create `test/utils/date_utils_test.dart`:
- Test auto week type alternation
- Test override takes priority
- Test shouldRingOnDate for singleRest (Saturday rings) and doubleRest (neither rings)
- Test custom weekday filtering
- Test edge cases: month boundaries, year boundaries

---

### Task 5: Alarm Storage Service

**Files:**
- Create: `lib/services/alarm_storage_service.dart`

- [ ] **Step 1: Implement database helper**

- Singleton pattern with `initDatabase()` (lazy, called from main)
- DB version 1, single table `alarms` with all AlarmInfo fields
- Columns match AlarmInfo fields

- [ ] **Step 2: Implement CRUD methods**

- `Future<List<AlarmInfo>> getAlarms()`
- `Future<int> insertAlarm(AlarmInfo alarm)`
- `Future<int> updateAlarm(AlarmInfo alarm)`
- `Future<int> deleteAlarm(int id)`
- `Future<int> toggleAlarm(int id, bool enabled)`

All methods handle the weekdays list: store as comma-separated string, parse on read.

- [ ] **Step 3: Write unit tests**

Create `test/services/alarm_storage_service_test.dart`:
- Test insert and read
- Test update fields
- Test toggle enabled state
- Test delete

---

### Task 6: Schedule Storage Service

**Files:**
- Create: `lib/services/schedule_storage_service.dart`

- [ ] **Step 1: Implement database helper**

Shares the same sqflite database as alarm storage (pass database instance or use singleton).

Table `week_schedules` with columns: id, year, month, week_of_month, week_type, created_at.
Unique constraint on (year, month, week_of_month).

- [ ] **Step 2: Implement CRUD methods**

- `Future<List<WeekSchedule>> getOverrides(int year, int month)`
- `Future<WeekSchedule?> getOverride(int year, int month, int weekOfMonth)`
- `Future<int> upsertOverride(WeekSchedule schedule)` — insert or replace
- `Future<int> deleteOverride(int id)`
- `Future<void> clearMonth(int year, int month)`

- [ ] **Step 3: Write unit tests**

Create `test/services/schedule_storage_service_test.dart`:
- Test getOverrides for a month
- Test upsert (insert new and update existing)
- Test delete
- Test clearMonth

---

### Task 7: Notification Service

**Files:**
- Create: `lib/services/alarm_notification_service.dart`

- [ ] **Step 1: Initialize flutter_local_notifications**

- Configure Android settings (notification channel "alarm_channel", importance: max, sound, vibration pattern)
- Request exact alarm permission on Android 12+
- Store notification ID mapping: `alarm_id → notification_id` for cancellation

- [ ] **Step 2: Implement show/cancel/dismiss**

- `Future<void> showAlarmNotification(AlarmInfo alarm)` — show with full-screen intent
- `Future<void> cancelAlarmNotification(int alarmId)` — cancel scheduled
- `Future<void> cancelAll()` — on app exit
- Notification payload includes alarm ID for deep linking to ringing screen

---

### Task 8: Scheduler Service (Next-Alarm Logic)

**Files:**
- Create: `lib/services/alarm_scheduler_service.dart`

- [ ] **Step 1: Implement schedule engine**

- `Future<void> scheduleAlarm(AlarmInfo alarm, List<WeekSchedule> overrides)`
- `Future<void> rescheduleAll(List<AlarmInfo> alarms, List<WeekSchedule> overrides)`
- `Future<void> cancelAlarm(int alarmId)`

Logic: calls `nextAlarmDate()` from date utils, schedules a one-shot notification via flutter_local_notifications at that DateTime.

- [ ] **Step 2: Handle device reboot**

- `Future<void> rescheduleOnBoot()` — read all enabled alarms from storage, reschedule
- Called from `BootReceiver` (platform-specific) or `AlarmBootReceiver` (Android manifest)

---

### Task 9: Alarm Provider

**Files:**
- Create: `lib/providers/alarm_provider.dart`

- [ ] **Step 1: Implement ChangeNotifier**

Fields:
- `List<AlarmInfo> _alarms`
- `bool _isLoading`

Methods:
- `Future<void> loadAlarms()` — read from storage, notify listeners
- `Future<void> addAlarm(AlarmInfo alarm)` — insert + schedule + notify
- `Future<void> updateAlarm(AlarmInfo alarm)` — update + reschedule + notify
- `Future<void> deleteAlarm(int id)` — delete + cancel + notify
- `Future<void> toggleAlarm(int id, bool enabled)` — toggle + schedule/cancel + notify

Each mutating method calls the corresponding storage service method, then the scheduler service, then `notifyListeners()`.

---

### Task 10: Timer Provider

**Files:**
- Create: `lib/providers/timer_provider.dart`

- [ ] **Step 1: Implement ChangeNotifier**

Fields:
- `int _totalSeconds` — target duration
- `int _remainingSeconds` — countdown
- `TimerState _state` — idle, running, paused, finished
- `DateTime? _startedAt`

Methods:
- `void setDuration(int seconds)` — set target
- `void start()` — begin countdown with periodic timer (1s interval)
- `void pause()` — pause, save elapsed
- `void resume()` — continue from saved
- `void reset()` — return to idle
- `void addMinute()` — add 60s while running
- `String get formattedTime` — MM:SS string

Emit `_remainingSeconds == 0` → set state to finished, notify.

---

### Task 11: Stopwatch Provider

**Files:**
- Create: `lib/providers/stopwatch_provider.dart`

- [ ] **Step 1: Implement ChangeNotifier**

Fields:
- `Duration _elapsed` — current elapsed time
- `StopwatchState _state` — idle, running, paused
- `List<Lap> _laps` — recorded laps
- `DateTime? _startedAt`

Lap struct:
```dart
class Lap {
  final int index;
  final Duration elapsed;
  final Duration lapTime;
}
```

Methods:
- `void start()` — start periodic timer (16ms for smooth centisecond display)
- `void pause()` — stop timer
- `void reset()` — clear all, return to zero
- `void lap()` — record current elapsed as new lap
- `String get formattedTime` — "MM:SS.cc" format

---

### Task 12: Schedule Provider

**Files:**
- Create: `lib/providers/schedule_provider.dart`

- [ ] **Step 1: Implement ChangeNotifier**

Fields:
- `int _currentYear`, `int _currentMonth` — viewed month
- `List<WeekSchedule> _overrides` — overrides for current month

Methods:
- `Future<void> loadMonth(int year, int month)`
- `Future<void> toggleWeekType(int year, int month, int weekOfMonth)` — toggle 单↔双 or remove override
- `WeekType effectiveWeekType(int year, int month, int weekOfMonth)` — resolve with override
- `Future<void> setParityShift(DateTime referenceDate)` — set week parity anchor

---

### Task 13: App Shell & Theme

**Files:**
- Create: `lib/app.dart`
- Create: `lib/screens/home_screen.dart`

- [ ] **Step 1: Define app theme in app.dart**

Material 3 theme using design system tokens:
- `ColorScheme.light(primary: Color(0xFFE8936A), ...)`
- `CardTheme: radius 20, elevation 0, color white`
- `AppBarTheme: transparent, foreground Color(0xFF3D2C2A)`
- `BottomNavigationBarTheme: selectedItemColor E8936A, unselectedItemColor 9A8A87`
- `Scaffold background: Color(0xFFFDF8F3)`
- `TextTheme: use Noto Sans SC via Google Fonts or system fallback`
- `ElevatedButton: rounded 12px, primary color`

- [ ] **Step 2: Build home_screen.dart with bottom navigation**

```dart
class HomeScreen extends StatefulWidget { ... }

// State fields:
int _currentIndex = 0;

// Body widgets list:
[
  const AlarmListScreen(),
  const ScheduleScreen(),
  const TimerScreen(),
  const StopwatchScreen(),
  const SettingsScreen(),
]

// BottomNavigationBar with 5 items:
// - 闹钟 (icon: Alarm)
// - 日程 (icon: CalendarMonth)
// - 计时 (icon: Timer)
// - 秒表 (icon: Stopwatch)
// - 设置 (icon: Settings)
```

- [ ] **Step 3: Update main.dart**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database (shared instance passed to storage services)
  final db = await openDatabase(...);  // or use AlarmStorageService singleton

  // Initialize notification service
  await AlarmNotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => StopwatchProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
      ],
      child: const AlarmClockApp(),
    ),
  );
}

class AlarmClockApp extends StatelessWidget {
  const AlarmClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '闹钟',
      theme: buildAlarmTheme(),  // from app.dart
      home: const HomeScreen(),
    );
  }
}
```

---

### Task 14: Alarm List Screen (Tab 1)

**Files:**
- Create: `lib/screens/alarm_list_screen.dart`
- Create: `lib/widgets/alarm_tile.dart`

- [ ] **Step 1: Build alarm list screen**

- `Consumer<AlarmProvider>` wrapping a `ListView`
- Shows empty state when no alarms (illustration + "添加闹钟" text)
- Each alarm is an `AlarmTile` widget
- FAB (FloatingActionButton) → navigate to AddEditAlarmScreen
- Pull-to-refresh via `RefreshIndicator`

- [ ] **Step 2: Build AlarmTile widget**

**Design (from prototype):**
- Card with 20px radius, white background, soft shadow
- Left: large 48px time display ("07:00"), below it small "AM" label
- Right: label text, repeat type chip (e.g., "单休" with peach bg, or "每日")
- Week badge: small chip showing "单周" or "双周" when pattern is singleRest/doubleRest
- Bottom-right: Android-style switch to enable/disable
- Swipe-to-delete (Dismissible) with red background + delete icon

- [ ] **Step 3: Wire navigation**

Tapping an alarm tile → navigate to `AddEditAlarmScreen(alarm: alarm)`.
FAB → navigate to `AddEditAlarmScreen()`.

---

### Task 15: Add/Edit Alarm Screen

**Files:**
- Create: `lib/screens/add_edit_alarm_screen.dart`
- Create: `lib/widgets/repeat_picker.dart`

- [ ] **Step 1: Build add/edit form

**Design (from prototype):**
- Transparent AppBar with back arrow + "保存" button
- Large centered time display (tap to show TimePicker)
- Below time: "取消闹钟" toggle switch
- Label text field
- Repeat type section: horizontal chips for 每日/工作日/周末/单周/双周/自定义
- When "自定义" selected, show weekday chips (一~日)
- When "单周" selected, show reference date picker
- 震动 toggle
- 贪睡分钟数 (5/10/15 selector)

- [ ] **Step 2: Build RepeatPicker widget**

- Horizontal scrollable `Wrap` or single-line `ListView`
- Chips: `ChoiceChip` with peach color when selected
- Options: 每日, 工作日, 周末, 单休, 双休, 自定义
- Callback: `onRepeatTypeChanged(RepeatType type)`

---

### Task 16: Schedule Screen (Tab 2 — 日程)

**Files:**
- Create: `lib/screens/schedule_screen.dart`
- Create: `lib/widgets/week_schedule_calendar.dart`

- [ ] **Step 1: Build schedule screen

**Design (from prototype):**
- Header: current month display with < > navigation arrows
- Week table headers: 周一 周二 周三 周四 周五 周六 周日
- Group days into weeks (rows)
- Each week row shows:
  - Days 1-7 with date numbers
  - At the end of the row: week badge showing "单休" or "双休"
  - Tap the badge → toggle between 单/双 (creates/removes override)
  - Override badge: slightly different styling with label "手动"
- Saturday/Sunday columns: visually dimmed (grey text)
- Different visual treatment for single-rest Saturday (some alarms may ring) vs double-rest weekend

- [ ] **Step 2: Wire with ScheduleProvider**

- Month navigation calls `provider.loadMonth(year, month)`
- Toggle badge calls `provider.toggleWeekType(year, month, weekOfMonth)`
- Re-render on provider change via Consumer

---

### Task 17: Timer Screen (Tab 3 — 计时)

**Files:**
- Create: `lib/screens/timer_screen.dart`
- Create: `lib/widgets/timer_picker.dart`
- Create: `lib/widgets/timer_presets.dart`

- [ ] **Step 1: Build timer screen

**Design (from prototype):**
- Three states: input mode, running mode, finished mode
- **Input mode:**
  - Center: scroll wheel picker (hours:minutes:seconds) using CupertinoPicker or custom
  - Below: quick preset chips: 1分钟, 3分钟, 5分钟, 10分钟, 15分钟, 30分钟
  - Bottom: prominent "开始" button (peach gradient, rounded)
- **Running mode:**
  - Large circular progress indicator (stroke width 6, peach gradient)
  - Center: remaining time "MM:SS" in large text
  - Below: "暂停" and "取消" buttons side by side
  - Optional: +1分钟 quick add button
- **Finished mode:**
  - Full screen pulse animation (or gentle bounce)
  - "时间到!" text
  - "确定" dismiss button

- [ ] **Step 2: Wire with TimerProvider**

- All controls call TimerProvider methods
- Use `Consumer<TimerProvider>` for reactive updates
- Timer dismisses and returns to input mode

---

### Task 18: Stopwatch Screen (Tab 4 — 秒表)

**Files:**
- Create: `lib/screens/stopwatch_screen.dart`

- [ ] **Step 1: Build stopwatch screen

**Design (from prototype):**
- Center: large time display "MM:SS.cc" (centiseconds)
- State: idle → show "00:00.00" with "开始" button
- Running → "计次" and "暂停" buttons
- Paused → "继续" and "重置" buttons
- Below: scrollable lap list
  - Each lap: lap number, lap time, total elapsed time
  - Latest lap highlighted
  - Best lap (fastest) marked with green text

- [ ] **Step 2: Wire with StopwatchProvider**

- Use `Consumer<StopwatchProvider>`
- Smooth centisecond updates via periodic 16ms timer
- Lap list rendered as ListView

---

### Task 19: Settings Screen (Tab 5 — 设置)

**Files:**
- Create: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Build settings screen

**Design (from prototype):**
- Sectioned ListView with card-style items
- **闹钟设置 section:**
  - 默认响铃时长 (picker: 5min/10min/15min/30min)
  - 默认贪睡 (picker: 5min/10min)
  - 响铃音量 (slider)
- **单双休设置 section:**
  - 当前周类型: "本周是单周" / "本周是双周" (read-only display)
  - 切换起始周: "本月从单周开始" / "本月从双周开始" toggle
  - 说明文字: explaining 单休(Sat ring) vs 双休(Sat+Sun off)
- **关于 section:**
  - App version
  - GitHub link (if applicable)

- [ ] **Step 2: Wire with ScheduleProvider**

- Toggle parity shift updates the reference date in ScheduleProvider
- Changes trigger recalculation of all alarm schedules

---

### Task 20: Ringing Screen

**Files:**
- Create: `lib/screens/alarm_ringing_screen.dart`

- [ ] **Step 1: Build full-screen ringing UI

**Design (from prototype):**
- Full screen overlay, no system UI (SystemChrome set to immersive)
- Background: warm gradient with gentle pulse animation
- Large time display
- Alarm label
- Snooze button: "贪睡 5分钟" (large, secondary style)
- Dismiss button: "关闭" (prominent, peach gradient)
- Swipe up to dismiss gesture

- [ ] **Step 2: Integrate with notification**

- `AlarmNotificationService` shows a full-screen intent notification
- Tapping notification opens `AlarmRingingScreen` with alarm ID as argument
- Screen reads alarm from provider and starts ringing:
  - Play alarm sound in loop (via `flutter_local_notifications` or `audioplayers`)
  - Vibrate pattern
- On dismiss: stop sound, cancel vibration, navigate to home
- On snooze: schedule next notification in N minutes, navigate to home

---

### Task 21: Boot Receiver (Android)

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/kotlin/.../AlarmBootReceiver.kt` (or Dart-level via flutter_local_notifications)

- [ ] **Step 1: Add boot receiver permission**

In `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

- [ ] **Step 2: Register receiver**

flutter_local_notifications handles boot rescheduling automatically when configured with `androidAllowWhileIdle: true` and `notificationChannel.showBadge: true`. If using a custom broadcast receiver, register it in the manifest.

- [ ] **Step 3: Reschedule on boot**

In `main.dart`, check if this is a cold start after boot, call `AlarmSchedulerService().rescheduleOnBoot()`.

---

## Implementation Order

The recommended order respects dependencies:

1. **Task 1** (setup) → must be first
2. **Tasks 2-3** (models) → no dependencies
3. **Task 4** (date utils) → depends on WeekSchedule model
4. **Tasks 5-6** (storage) → depends on models
5. **Tasks 7-8** (notifications + scheduler) → depends on date utils, storage, models
6. **Tasks 9-12** (providers) → depends on services
7. **Tasks 13** (app shell + theme) → depends on nothing else code-wise, but best done before screens
8. **Tasks 14-19** (screens) → depends on providers, widgets
9. **Task 20** (ringing screen) → depends on notification service
10. **Task 21** (boot receiver) → depends on scheduler

**Parallel-eligible groups:** (2+3), (5+6), (9+10+11+12), (14+16+17+18+19)

---

## Testing Strategy

- **Unit tests** for models (Tasks 2-3), date utils (Task 4), and services (Tasks 5-6)
- **Widget tests** for each screen (basic rendering, user interaction)
- **Integration test** for the full alarm creation → display flow (optional, can be deferred)
- Run `flutter test` after each group of tasks
- Run `flutter analyze` before any commit

---

## Notes

- All Chinese UI strings use the design established in the HTML prototype
- The schedule calendar view is a read-first feature: it displays the current month's week types and allows per-week toggling
- Timer and stopwatch are local-only features with no persistence (state resets on app restart)
- Ringing screen is the only screen launched as a full-screen intent (over lock screen)
- The warm peach design system should be consistently applied across all screens
