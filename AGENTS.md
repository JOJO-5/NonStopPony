# AGENTS.md — alarm_clock

## Project State

Fresh Flutter project (`flutter create` template) — counter app in `lib/main.dart`, not yet modified. No git repo initialized. Implementation planned but not started.

## Current Reality

- **Entrypoint**: `lib/main.dart` — default `MyApp` / `MyHomePage` counter widget
- **Test**: `test/widget_test.dart` — single smoke test for counter increment
- **Only existing file**: `lib/main.dart` is the sole source file
- **Git**: Not initialized. `git init` required before any commits.

## Planned Architecture

The project is scoped to become an alarm clock app with 单双周 (alternating single/double rest weekend) scheduling. Do not deviate from this stack without explicit instruction:

| Layer | Technology |
|---|---|
| State | Provider (ChangeNotifier) |
| Persistence | sqflite |
| Notifications | flutter_local_notifications |
| Formatting | intl package |
| Linting | flutter_lints (default rules) |

Planned structure (create these as implementation progresses):
- `lib/models/alarm_info.dart` — AlarmInfo model + RepeatType enum
- `lib/providers/alarm_provider.dart` — ChangeNotifier for CRUD + scheduling
- `lib/services/alarm_storage_service.dart` — sqflite operations
- `lib/services/alarm_notification_service.dart` — notification lifecycle
- `lib/services/alarm_scheduler_service.dart` — 单双周 parity logic + next-alarm calc
- `lib/screens/` — alarm list, add/edit form, full-screen ringing
- `lib/widgets/` — alarm tile, repeat picker
- `lib/utils/date_utils.dart` — week parity, day label formatting
- `lib/app.dart` — MaterialApp + theme

## Commands

```bash
# Run
flutter run                          # pick device interactively
flutter run -d <device_id>           # target specific device

# Analyze
flutter analyze                      # required before all commits — passes the default lint set

# Test
flutter test                         # all tests
flutter test test/path/to_test.dart  # single file

# Dependencies
flutter pub get                      # installs from https://pub.flutter-io.cn (configured in pubspec.lock)
flutter pub add <package>            # add a dependency
flutter pub upgrade --major-versions # major version bump
flutter pub outdated                 # check for newer versions

# Build
flutter build apk --debug            # Android debug APK
flutter build ios --no-codesign      # iOS build without signing
flutter build web                    # web build
```

## Key Constraints

- **Pub mirror**: `https://pub.flutter-io.cn` (China) — do not switch to default pub.dev without approval.
- **SDK**: `^3.9.2`, Flutter stable channel (revision `a402d9a4`).
- **Analysis options**: `package:flutter_lints/flutter.yaml` — do not add custom rules without approval.
- **No CI/CD**: No workflows configured yet.
- **Platform targets**: Android, iOS, web, Linux, macOS, Windows all scaffolded.

## Testing

- `flutter_test` from SDK is the only test framework. No mock/contract testing framework installed.
- Widget tests use `WidgetTester` (material library pattern). Existing test uses `pumpWidget`/`pump`/`find`.
- No integration tests configured.
- When writing model tests, they do not need Flutter dependencies — plain Dart `test` package tests are sufficient for non-widget models.

## Conventions

- Dart naming: `lowercase_with_underscores` for files, `lowerCamelCase` for variables/functions, `UpperCamelCase` for types.
- Use `const` constructors where possible.
- Follow the existing plan at `docs/superpowers/plans/2026-05-20-alarm-clock.md` for implementation order and file structure.
- All model serialization uses `toMap()`/`fromMap()` pattern for sqflite.
- Chinese UI strings use fullwidth characters where applicable (e.g., 单双周, 星期一～星期七).

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **alarm_clock** (1551 symbols, 3593 relationships, 127 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

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
