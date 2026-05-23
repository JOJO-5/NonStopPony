# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter run                          # pick device
flutter analyze                      # lint check before commits
flutter test                         # all tests
flutter test test/path/to_test.dart  # single test file
flutter pub get                      # install deps (China mirror: pub.flutter-io.cn)
flutter pub add <pkg>                # add dependency
flutter build apk --debug            # Android debug APK
```

## Architecture

Flutter alarm clock with 单双休 (alternating single/double rest weekend) scheduling.

**Stack:** Flutter 3.35, Dart 3.9, Provider (ChangeNotifier), sqflite, flutter_local_notifications, intl, google_fonts, timezone, shared_preferences

### Project Structure

```
lib/
├── main.dart               # Entry: init DBs, timezone, notifications, method channel
├── app.dart                # MaterialApp + Material 3 theme (warm peach palette)
├── models/
│   ├── alarm_info.dart     # AlarmInfo + RepeatType enum (7 variants including singleRest/doubleRest)
│   └── week_schedule.dart  # WeekSchedule model + WeekType enum (single/double override)
├── providers/
│   ├── alarm_provider.dart       # Alarm CRUD, delegates scheduling to AlarmSchedulerService
│   ├── schedule_provider.dart    # Week schedule override CRUD, resolves week type
│   ├── timer_provider.dart       # Countdown timer (idle/running/paused/finished)
│   └── stopwatch_provider.dart   # Stopwatch with lap tracking
├── services/
│   ├── alarm_storage_service.dart      # sqflite CRUD for alarms table
│   ├── schedule_storage_service.dart   # sqflite CRUD for week_schedule table (separate table, same DB)
│   ├── alarm_notification_service.dart # Singleton wrapping flutter_local_notifications
│   ├── alarm_scheduler_service.dart    # 单双休 next-algo engine, schedules via notification service
│   └── boot_receiver_service.dart      # Reschedule all alarms after device boot
├── screens/ (5-tab HomeScreen: 闹钟, 日程, 计时, 秒表, 设置)
│   ├── home_screen.dart                # BottomNavigationBar + IndexedStack
│   ├── alarm_list_screen.dart          # Alarm list + FAB
│   ├── add_edit_alarm_screen.dart      # Create/edit form
│   ├── ringing_screen.dart             # Full-screen alarm overlay
│   ├── schedule_screen.dart            # Monthly calendar with per-week 单/双 toggle
│   ├── timer_screen.dart               # Countdown (picker, progress, finish state)
│   ├── stopwatch_screen.dart           # Stopwatch + lap list
│   └── settings_screen.dart            # Preferences
├── widgets/
│   ├── alarm_tile.dart                 # Alarm card: time, label, repeat, switch
│   ├── repeat_picker.dart              # Repeat type chip selector
│   ├── week_schedule_calendar.dart     # Month grid with week type badges
│   ├── timer_picker.dart               # Duration picker
│   └── timer_presets.dart             # Quick preset chips
└── utils/
    └── date_utils.dart    # Week parity, shouldRingOnDate, nextAlarmDate, labels
```

### Key Patterns

- **State:** `ChangeNotifier` + `Provider`/`Consumer`. No other state management.
- **Providers register in `main.dart` via `MultiProvider`, re-provided in `app.dart` via `.value`.
- **Persistence:** Two sqflite tables (`alarms`, `week_schedule`) in `alarm_clock.db`.
- **Singleton:** `AlarmNotificationService()` — factory pattern, shared instance.
- **Static service methods:** `AlarmStorageService`, `ScheduleStorageService`, `AlarmSchedulerService`, `BootReceiverService`.
- **Serialization:** All models implement `toMap()`/`fromMap()` for sqflite.
- **Boot receiver:** `MethodChannel('com.example.alarm_clock/boot_receiver')` for Android boot rescheduling.

### 单双休 Schedule Engine (lib/utils/date_utils.dart)

- **Week parity:** Counts weeks since epoch `2024-01-01` (odd=单休, even=双休).
- **Resolution order:** Manual override > auto parity.
- **`resolveWeekType(date, overrides)`** — checks `week_schedule` table by (year, month, weekOfMonth), falls back to `autoWeekType`.
- **`shouldRingOnDate(alarm, date, overrides)`** — core decision function:
  - `singleRest`: weekdays ring, Saturday rings only if single-rest week, Sunday never rings
  - `doubleRest`: weekdays ring, Sat+Sun never ring
  - `custom`: rings only on selected weekdays
- **`nextAlarmDate()`** — linear scan up to 365 days forward.

### Design System

| Token | Value | Usage |
|---|---|---|
| Background | `#FDF8F3` | scaffold |
| Primary | `#E8936A` | accent/selected |
| Secondary | `#FAD0B4` | soft sunrise |
| Gradient | 180deg `#FAD0B4` → `#FCE6D2` | — |
| Text primary | `#3D2C2C` | headings |
| Text secondary | `#9E9E9E` | muted |
| Danger | `#E85A5A` | delete/ringing |
| Success | `#6BBF8A` | 双休 indicator |
| Card radius | 20px | cards |
| Typography | Noto Sans SC (google_fonts) | all text |

### 单双休 Semantics

- **单休 (single rest):** Saturday is a work day (alarm rings). Sunday is off.
- **双休 (double rest):** Both Saturday and Sunday are off.
- Week type auto-alternates: odd week = 单休, even week = 双休.
- Per-week overrides stored in `week_schedule` table override the auto pattern.
- Settings screen shows current week type (read-only).

---

# Behavioral Guidelines

See C:\Users\JOJO\.claude\CLAUDE.md for Karpathy behavioral coding guidelines applied globally.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **alarm_clock** (1464 symbols, 3279 relationships, 101 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/alarm_clock/context` | Codebase overview, check index freshness |
| `gitnexus://repo/alarm_clock/clusters` | All functional areas |
| `gitnexus://repo/alarm_clock/processes` | All execution flows |
| `gitnexus://repo/alarm_clock/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
