export const meta = {
  name: 'chrono-migration',
  description: 'Phase-by-phase migration of Chrono features into 战马闹钟, ordered by value/effort ratio',
  phases: [
    { title: 'Phase 1: Quick Wins', detail: 'Onboarding, color schemes, alarm skip/snooze (3 parallel agents)' },
    { title: 'Phase 1 Verify', detail: 'Analyze + test + build after Phase 1' },
    { title: 'Phase 2: Core UX', detail: 'Alarm challenges, multi-mode timer picker (2 parallel agents)' },
    { title: 'Phase 2 Verify', detail: 'Analyze + test + build after Phase 2' },
    { title: 'Phase 3: Polish', detail: 'Ringtone manager, alarm history, date range schedules (3 parallel agents)' },
    { title: 'Phase 3 Verify', detail: 'Analyze + test + build after Phase 3' },
    { title: 'Phase 4: Big Features', detail: 'World clock, settings framework (2 parallel agents)' },
    { title: 'Phase 4 Verify', detail: 'Analyze + test + build after Phase 4' },
    { title: 'Phase 5: Nice-to-Have', detail: 'Dynamic color, dev settings, quick actions, backup (4 parallel agents)' },
    { title: 'Final Verify', detail: 'Full test suite + APK build + feature integrity check' },
  ],
}

// ═══════════════════════════════════════════════════════════════════════════
// CHRONO FEATURE MIGRATION WORKFLOW — PARALLEL VERSION
// Reference: https://github.com/vicolo-dev/chrono.git
// Target: D:/mengfanliuFile/dev/clound/alarm_clock
//
// Each phase: all features run in parallel via parallel([]), then verify.
// Phases are sequential — each phase depends on prior phase stability.
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
phase('Phase 1: Quick Wins')

log('Phase 1 — launching 3 parallel agents: onboarding, color schemes, alarm skip')
const [onboardingResult, colorSchemeResult, skipResult] = await parallel([
  // ── 1.1 Onboarding Screen ───────────────────────────────────────────────
  () => agent(
    `Implement an onboarding screen for the 战马闹钟 alarm clock app.

CONTEXT:
- Chrono onboarding reference: lib/onboarding/screens/onboarding_screen.dart
- Target project: D:/mengfanliuFile/dev/clound/alarm_clock

WHAT TO DO:
1. Add introduction_screen package to pubspec.yaml
2. Create lib/screens/onboarding_screen.dart with 3-4 pages explaining app features
   - One page about battery optimization (critical for alarm reliability)
   - Uses brand colors (kBrandCopper, kBrandWarmBg, kBrandBrown)
   - Chinese text, Noto Sans SC font
3. On completion: save 'onboarded'=true to SharedPreferences, navigate to HomeScreen
4. In main.dart: check 'onboarded' key, show OnboardingScreen on first launch
5. Match existing app theme from lib/theme/app_theme.dart

IMPORTANT: Read existing files before changes. Match existing code style. After coding: flutter analyze && flutter test. Report any failures.`,
    { label: '1.1-onboarding', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
        issues: { type: 'array', items: { type: 'string' } },
      },
      required: ['files_created', 'files_modified', 'analyze_result', 'test_result']
    }},
  ),

  // ── 1.2 Multiple Preset Color Schemes ───────────────────────────────────
  () => agent(
    `Add multiple preset color schemes to the alarm clock app.

CONTEXT:
- Chrono reference: lib/theme/data/default_color_schemes.dart
- Existing theme files: lib/theme/app_theme.dart, lib/theme/theme_provider.dart
- App currently has 1 fixed brand palette (warm copper/brown)

WHAT TO DO:
1. Create lib/theme/color_schemes.dart with 3 ColorSchemeData presets:
   - Warm Copper (default, existing brand)
   - Ocean Blue
   - Forest Green
2. Extend ThemeProvider to store selected scheme index in SharedPreferences
3. Update buildLightTheme/buildDarkTheme to accept a ColorSchemeData parameter
4. Add color scheme selector in settings_screen.dart (row of 3 color dots)
5. Wrap in Consumer<ThemeProvider> for immediate apply

IMPORTANT: Keep existing brand as DEFAULT (index 0). All existing tests must pass. Run flutter analyze.`,
    { label: '1.2-color-schemes', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified', 'analyze_result', 'test_result']
    }},
  ),

  // ── 1.3 Alarm Skip/Snooze per Occurrence ────────────────────────────────
  () => agent(
    `Add per-occurrence alarm skip and snooze count tracking.

CONTEXT:
- Chrono alarm model: lib/alarm/types/alarm.dart
- Existing alarm model: lib/models/alarm_info.dart
- Existing alarm provider: lib/providers/alarm_provider.dart
- Existing alarm scheduler: lib/services/alarm_scheduler_service.dart

WHAT TO DO:
1. Add to AlarmInfo model (lib/models/alarm_info.dart):
   - int snoozeCount (default 0), int maxSnoozeCount (default 3)
   - DateTime? skippedDate
   - Update toMap()/fromMap()/copyWith()
2. Add skip()/cancelSkip() methods to AlarmProvider that update skippedDate and reschedule
3. Update alarm_fullscreen_screen.dart:
   - Show "贪睡 1/3" indicator
   - Add "跳过本次" (skip this occurrence) button
4. Update calculateNextTrigger to skip dates matching skippedDate
5. DB migration: bump _dbVersion, ALTER TABLE ADD COLUMN in onUpgrade

IMPORTANT: DB migration must be backward-compatible. All 102 existing tests must pass. Run flutter analyze.`,
    { label: '1.3-alarm-skip', schema: {
      type: 'object',
      properties: {
        files_modified: { type: 'array', items: { type: 'string' } },
        db_version_new: { type: 'number' },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_modified', 'analyze_result', 'test_result']
    }},
  ),
])

// ── Phase 1 Verification ─────────────────────────────────────────────────
phase('Phase 1 Verify')
log('Phase 1 parallel agents complete — running verification')
const phase1Verify = await agent(
  `Verify Phase 1 migration. Run: flutter analyze, flutter test, flutter build apk --debug.
Report: analyze issue count, test pass/fail, build success, any incomplete files.`,
  { schema: {
    type: 'object',
    properties: {
      analyze_issues: { type: 'number' },
      tests_passed: { type: 'number' },
      tests_failed: { type: 'number' },
      build_success: { type: 'boolean' },
      incomplete_files: { type: 'array', items: { type: 'string' } },
    },
    required: ['analyze_issues', 'tests_passed', 'tests_failed', 'build_success']
  }},
)

// ═══════════════════════════════════════════════════════════════════════════
phase('Phase 2: Core UX')

log('Phase 2 — launching 2 parallel agents: alarm challenges, timer picker modes')
const [challengesResult, pickerResult] = await parallel([
  // ── 2.1 Alarm Dismiss Challenges ────────────────────────────────────────
  () => agent(
    `Implement alarm dismiss challenges (闹钟任务) to prevent oversleeping.

CONTEXT:
- Chrono task references: lib/alarm/widgets/tasks/ (math_task, retype_task, sequence_task)
- Existing alarm fullscreen: lib/screens/alarm_fullscreen_screen.dart
- Existing alarm model: lib/models/alarm_info.dart

WHAT TO DO:
1. Read the Chrono task widgets to understand their interfaces
2. Add AlarmTaskType enum to alarm_info.dart: none, math, retype, sequence
3. Add taskType field to AlarmInfo model (default: none)
4. Create 3 simplified task widgets in lib/widgets/tasks/:
   - math_challenge.dart — addition/subtraction with number pad
   - retype_challenge.dart — type a displayed word exactly
   - sequence_challenge.dart — tap numbers in ascending order
5. Update alarm_fullscreen_screen.dart:
   - If taskType != none, show task widget instead of dismiss button
   - Task completion triggers dismissAlarm()
6. Update add_edit_alarm_screen.dart with task type selector

IMPORTANT: Keep tasks SIMPLE. Match brand colors and card styles. All existing tests must pass. Run flutter analyze.`,
    { label: '2.1-challenges', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified', 'analyze_result', 'test_result']
    }},
  ),

  // ── 2.2 Multiple Timer Picker Modes ─────────────────────────────────────
  () => agent(
    `Add a clock-face dial duration picker to the timer screen.

CONTEXT:
- Chrono reference: lib/timer/widgets/dial_duration_picker.dart
- Existing timer picker: lib/widgets/timer_picker.dart (3-wheel ListWheelScrollView)
- Existing timer screen: lib/screens/timer_screen.dart

WHAT TO DO:
1. Read Chrono's dial_duration_picker.dart for the interaction pattern
2. Create lib/widgets/dial_duration_picker.dart:
   - Circular clock-face with 12 hour markers + 60 minute ticks
   - Draggable hour and minute hands via GestureDetector onPanUpdate
   - Duration display (HH:MM:SS) in center
   - Brand colors (kBrandCopper hands, kBrandBrown markers)
   - Use CustomPainter for smooth 60fps rendering
3. Add picker mode toggle button to timer_screen.dart
4. Preserve duration when switching between dial and scroll modes
5. Both pickers share the same duration state

IMPORTANT: Dial picker must feel SMOOTH. Keep existing scroll wheel picker unchanged. All timer tests must pass. Run flutter analyze.`,
    { label: '2.2-picker-modes', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified', 'analyze_result', 'test_result']
    }},
  ),
])

// ── Phase 2 Verification ─────────────────────────────────────────────────
phase('Phase 2 Verify')
log('Phase 2 parallel agents complete — running verification')
const phase2Verify = await agent(
  `Verify Phase 2. Run: flutter analyze, flutter test, flutter build apk --debug.
Report issues, test counts, build status.`,
  { schema: {
    type: 'object',
    properties: {
      analyze_issues: { type: 'number' },
      tests_passed: { type: 'number' },
      tests_failed: { type: 'number' },
      build_success: { type: 'boolean' },
    },
    required: ['analyze_issues', 'tests_passed', 'tests_failed', 'build_success']
  }},
)

// ═══════════════════════════════════════════════════════════════════════════
phase('Phase 3: Polish')

log('Phase 3 — launching 3 parallel agents: ringtone, alarm history, date schedules')
const [ringtoneResult, historyResult, dateScheduleResult] = await parallel([
  // ── 3.1 Ringtone Manager ────────────────────────────────────────────────
  () => agent(
    `Enhance ringtone management.

CONTEXT:
- Chrono reference: lib/audio/logic/ringtones.dart
- Existing: basic MethodChannel ringtone picker in add_edit_alarm_screen.dart

WHAT TO DO:
1. Create lib/services/ringtone_service.dart:
   - getSystemRingtones() — fetch system alarm sounds
   - importRingtone(filePath) — copy file to app ringtone dir
   - deleteCustomRingtone(uri)
2. Create lib/screens/ringtone_picker_screen.dart:
   - "系统铃声" and "自定义铃声" sections
   - Play/pause preview for each ringtone
   - Selected ringtone highlighted in brand color
   - "导入铃声" button for file import
3. Update add_edit_alarm_screen.dart to use the new picker screen
4. Add flutter_system_ringtones package if not present

IMPORTANT: Keep existing MethodChannel path as fallback. Run flutter analyze && flutter test.`,
    { label: '3.1-ringtone', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified']
    }},
  ),

  // ── 3.2 Alarm Event History ─────────────────────────────────────────────
  () => agent(
    `Add alarm event history tracking.

CONTEXT:
- Chrono reference: lib/alarm/screens/alarm_events_screen.dart
- Existing: no event logging

WHAT TO DO:
1. Create lib/models/alarm_event.dart (id, alarmId, firedAt, action)
   - toMap()/fromMap() for sqflite
2. Add alarm_events table to alarm_storage_service.dart
   - insertEvent() and getEvents() methods
3. Log events from alarm_fullscreen_screen.dart on dismiss/snooze/skip
4. Create lib/screens/alarm_history_screen.dart:
   - ListView grouped by date (今天, 昨天, 更早)
   - Each entry: alarm time, label, action icon
5. Add "闹钟记录" tile in settings screen

DB migration must be backward-compatible. Run flutter analyze && flutter test.`,
    { label: '3.2-history', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified']
    }},
  ),

  // ── 3.3 Date Range Alarm Schedules ──────────────────────────────────────
  () => agent(
    `Add "specific dates" and "date range" repeat types.

CONTEXT:
- Chrono refs: lib/alarm/types/schedules/dates_alarm_schedule.dart, range_alarm_schedule.dart
- Existing repeat types: once, daily, weekdays, weekends, singleRest, doubleRest, custom

WHAT TO DO:
1. Add RepeatType.dates and RepeatType.range to enum in alarm_info.dart
2. Add fields: List<DateTime>? specificDates, DateTime? rangeStart, DateTime? rangeEnd
   - Update toMap()/fromMap() (serialize dates as comma-separated ISO strings)
3. Update shouldRingOnDate in date_utils.dart for new types
4. Update add_edit_alarm_screen.dart with date pickers for new types
5. Update calculateNextTrigger in alarm_scheduler_service.dart

DB migration needed. Keep 单双休 logic unchanged. Run flutter analyze && flutter test.`,
    { label: '3.3-date-schedules', schema: {
      type: 'object',
      properties: {
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_modified']
    }},
  ),
])

// ── Phase 3 Verification ─────────────────────────────────────────────────
phase('Phase 3 Verify')
log('Phase 3 parallel agents complete — running verification')
const phase3Verify = await agent(
  `Verify Phase 3. Run: flutter analyze, flutter test, flutter build apk --debug.
Report issues, test counts, build status.`,
  { schema: {
    type: 'object',
    properties: {
      analyze_issues: { type: 'number' },
      tests_passed: { type: 'number' },
      tests_failed: { type: 'number' },
      build_success: { type: 'boolean' },
    },
    required: ['analyze_issues', 'tests_passed', 'tests_failed', 'build_success']
  }},
)

// ═══════════════════════════════════════════════════════════════════════════
phase('Phase 4: Big Features')

log('Phase 4 — launching 2 parallel agents: world clock, settings framework')
const [worldClockResult, settingsResult] = await parallel([
  // ── 4.1 World Clock ─────────────────────────────────────────────────────
  () => agent(
    `Implement World Clock feature.

CONTEXT:
- Chrono refs: clock_screen.dart, search_city_screen.dart, types/city.dart,
  widgets/timezone_card.dart, logic/timezone_database.dart (all under lib/clock/)
- Existing tabs: 闹钟, 日程, 计时, 秒表, 设置 (5 tabs)

WHAT TO DO:
1. Create lib/models/city.dart (name, country, timezone, isFavorite)
2. Create lib/screens/world_clock_screen.dart:
   - Digital clock at top
   - List of favorite city timezone cards (city name, country, time, offset)
   - FAB to add cities
3. Create lib/screens/search_city_screen.dart:
   - Search bar + filtered list of ~50 major world cities
   - Tap to add to favorites
4. Create lib/widgets/timezone_card.dart
5. Integrate into navigation — decide best approach (new tab, replace schedule tab, or settings entry)
   - RECOMMENDATION: move schedule to a settings sub-page, add clock as tab

IMPORTANT: tz package already imported. Run flutter analyze && flutter test.`,
    { label: '4.1-world-clock', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        integration_decision: { type: 'string' },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified', 'integration_decision']
    }},
  ),

  // ── 4.2 Simplified Settings Framework ───────────────────────────────────
  () => agent(
    `Create a simplified schema-driven settings framework.

CONTEXT:
- Chrono refs: types/setting.dart, types/setting_group.dart,
  widgets/switch_setting_card.dart, widgets/select_setting_card.dart (under lib/settings/)
- Existing: lib/screens/settings_screen.dart (single large file)

WHAT TO DO (SIMPLIFIED — not full Chrono clone):
1. Create lib/settings/setting_types.dart:
   - enum SettingType { switch, select, slider, action }
   - class Setting, SettingOption, SettingGroup
2. Create lib/settings/setting_cards.dart with 3 card widgets:
   - SwitchSettingCard, SelectSettingCard, ActionSettingCard
3. Refactor settings_screen.dart to use the framework
4. Migrate 5 settings: dark mode, vibration, snooze minutes, ringtone, about

Keep it SIMPLE. Don't over-engineer. All tests must pass. Run flutter analyze.`,
    { label: '4.2-settings', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified']
    }},
  ),
])

// ── Phase 4 Verification ─────────────────────────────────────────────────
phase('Phase 4 Verify')
log('Phase 4 parallel agents complete — running verification')
const phase4Verify = await agent(
  `Verify Phase 4. Run: flutter analyze, flutter test, flutter build apk --debug.
Report issues, test counts, build status.`,
  { schema: {
    type: 'object',
    properties: {
      analyze_issues: { type: 'number' },
      tests_passed: { type: 'number' },
      tests_failed: { type: 'number' },
      build_success: { type: 'boolean' },
    },
    required: ['analyze_issues', 'tests_passed', 'tests_failed', 'build_success']
  }},
)

// ═══════════════════════════════════════════════════════════════════════════
phase('Phase 5: Nice-to-Have')

log('Phase 5 — launching 4 parallel agents: dynamic color, dev settings, quick actions, backup')
const [dynamicColorResult, devSettingsResult, quickActionsResult, backupResult] = await parallel([
  // ── 5.1 Dynamic Color ───────────────────────────────────────────────────
  () => agent(
    `Add Material You dynamic color support.

CONTEXT:
- Existing theme: lib/theme/app_theme.dart, lib/theme/theme_provider.dart
- App uses warm copper/brown brand palette

WHAT TO DO:
1. Add dynamic_color package to pubspec.yaml
2. In ThemeProvider: add useDynamicColor boolean preference
3. In app.dart theme builder: use DynamicColorBuilder when toggle is on
4. Add "使用系统取色" toggle in settings
5. Fall back to brand colors when dynamic color unavailable

Keep it SIMPLE. All tests pass. Run flutter analyze.`,
    { label: '5.1-dynamic-color', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_modified']
    }},
  ),

  // ── 5.2 Developer Settings ──────────────────────────────────────────────
  () => agent(
    `Add hidden developer settings screen.

CONTEXT:
- Existing settings: lib/screens/settings_screen.dart
- App has version text at bottom of settings

WHAT TO DO:
1. Create lib/screens/developer_screen.dart:
   - Show: app version, DB path, DB file size
   - Buttons: "Clear Database", "Reset Onboarding", "Export Logs"
   - Simple Scaffold with ListView
2. In settings_screen.dart: GestureDetector on version text, count taps
3. After 7 taps: Navigator.push to DeveloperScreen
4. Brand colors, Noto Sans SC font

Keep it SIMPLE. All tests pass. Run flutter analyze.`,
    { label: '5.2-dev-settings', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified']
    }},
  ),

  // ── 5.3 Quick Actions ───────────────────────────────────────────────────
  () => agent(
    `Add home screen quick actions (App Shortcuts).

CONTEXT:
- Existing: lib/main.dart, lib/app.dart with HomeScreen
- Target: Android home screen long-press shortcuts

WHAT TO DO:
1. Add quick_actions package to pubspec.yaml
2. Register 2 shortcuts in main.dart:
   - "新建闹钟" → navigate to AddEditAlarmScreen
   - "开始计时" → navigate to TimerScreen
3. Use QuickActions().initialize with handler that uses GlobalKey<NavigatorState>

Keep it SIMPLE. All tests pass. Run flutter analyze.`,
    { label: '5.3-quick-actions', schema: {
      type: 'object',
      properties: {
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
      },
      required: ['files_modified']
    }},
  ),

  // ── 5.4 Settings Backup/Restore ─────────────────────────────────────────
  () => agent(
    `Add alarm data backup and restore feature.

CONTEXT:
- Existing storage: alarm_storage_service.dart, schedule_storage_service.dart
- Data lives in alarm_clock.db (sqflite)

WHAT TO DO:
1. Add share_plus and file_picker packages to pubspec.yaml
2. Create lib/services/backup_service.dart:
   - exportData(): read all alarms+schedules → JSON string
   - importData(json): parse JSON → write to DB
3. Add "导出数据" button in settings → share JSON file
4. Add "导入数据" button in settings → pick file → import
5. Show SnackBar on success/failure

Keep it SIMPLE. All tests pass. Run flutter analyze.`,
    { label: '5.4-backup', schema: {
      type: 'object',
      properties: {
        files_created: { type: 'array', items: { type: 'string' } },
        files_modified: { type: 'array', items: { type: 'string' } },
        analyze_result: { type: 'string' },
        test_result: { type: 'string' },
      },
      required: ['files_created', 'files_modified']
    }},
  ),
])

// ═══════════════════════════════════════════════════════════════════════════
phase('Final Verify')

log('All 5 phases complete — running final comprehensive verification')
const finalVerify = await agent(
  `FINAL VERIFICATION of the complete Chrono migration.

Run ALL checks:
1. flutter analyze — report ALL issues (count by severity)
2. flutter test — report pass/fail, list any failures
3. flutter build apk --debug — success/failure, APK path
4. Check for TODO/FIXME/HACK comments in lib/
5. Count total Dart files before vs after
6. Verify 战马闹钟 unique features intact (grep for):
   - shouldRingOnDate, resolveWeekType, weekNumber
   - HolidayService, saturdayHour, 单休/双休

Report comprehensive migration summary.`,
  { schema: {
    type: 'object',
    properties: {
      analyze_errors: { type: 'number' },
      analyze_warnings: { type: 'number' },
      tests_passed: { type: 'number' },
      tests_failed: { type: 'number' },
      build_success: { type: 'boolean' },
      apk_path: { type: 'string' },
      total_dart_files: { type: 'number' },
      unique_features_intact: { type: 'boolean' },
      todo_count: { type: 'number' },
      summary: { type: 'string' },
    },
    required: ['analyze_errors', 'tests_passed', 'tests_failed', 'build_success', 'unique_features_intact']
  }},
)

return {
  phase1: { onboarding: onboardingResult, color_schemes: colorSchemeResult, alarm_skip: skipResult, verify: phase1Verify },
  phase2: { challenges: challengesResult, picker_modes: pickerResult, verify: phase2Verify },
  phase3: { ringtone: ringtoneResult, history: historyResult, date_schedules: dateScheduleResult, verify: phase3Verify },
  phase4: { world_clock: worldClockResult, settings: settingsResult, verify: phase4Verify },
  phase5: { dynamic_color: dynamicColorResult, dev_settings: devSettingsResult, quick_actions: quickActionsResult, backup: backupResult },
  final_verify: finalVerify,
}
