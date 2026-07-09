# 战马闹钟 🐎

A smart alarm clock app built with Flutter, designed specifically for **alternating single/double weekend (单双周)** work schedules.

Supports Chinese statutory holidays — alarms skip during holidays and ring on makeup workdays automatically.

---

## Features

### ⏰ Alarm Clock
- **Repeat modes**: Once, Daily, Weekdays, Weekends, Custom
- **Single/Double weekend scheduling (单双周)**: Automatically determines whether the current week is a "single rest" or "double rest" week based on a reference date (default: 2024-01-01)
- **Week type override**: Manually switch between single/double week mode
- **Holiday awareness**: Skips statutory holidays, rings on makeup workdays
- **Custom ringtone**: System ringtones + custom audio files

### 🔧 Utilities
- **Timer**: Countdown with background audio and lock-screen alarm
- **Stopwatch**: Lap timing with split records
- **Calendar**: Monthly view with manual single/double week toggle

---

## Architecture

| Layer | Technology |
|-------|------------|
| State | Provider (ChangeNotifier) |
| Persistence | sqflite |
| Notifications | flutter_local_notifications |
| Date logic | intl package |

### Key Modules

```
lib/
├── models/
│   ├── alarm_info.dart       # Alarm model + RepeatType enum
│   └── week_schedule.dart    # Single/double week type + parity logic
├── providers/
│   ├── alarm_provider.dart       # Alarm CRUD + scheduling
│   └── schedule_provider.dart    # Week type chain-linkage override logic
├── services/
│   ├── alarm_storage_service.dart      # SQLite persistence
│   ├── alarm_notification_service.dart  # Notification lifecycle
│   └── alarm_scheduler_service.dart     # Next alarm calculation + holiday logic
├── screens/                  # Alarm list, add/edit form, ringing UI
├── widgets/                  # Reusable components
└── utils/
    └── date_utils.dart       # shouldRingOnDate, week parity, holiday lookup
```

---

## Getting Started

### Prerequisites
- Flutter SDK 3.9+ (stable channel)
- Android SDK (minSdkVersion 23 / Android 6.0)
- For release builds: Java 17 + Android signing keystore

### Run

```bash
flutter pub get
flutter run
```

### Test

```bash
flutter analyze    # Lint + type check
flutter test       # Unit + widget tests
```

### Build

```bash
# Debug APK
flutter build apk --debug

# Release APK (per-ABI split)
flutter build apk --release --split-per-abi

# Web
flutter build web

# iOS (requires macOS)
flutter build ios --no-codesign
```

---

## CI / Release

Every push to `master` triggers:
1. `flutter analyze` — lint + type check
2. `flutter test` — all tests
3. `flutter build apk` — Android debug APK
4. `flutter build web` — Web build

Every tag matching `v*` additionally:
- Builds signed release APK (per ABI) + App Bundle (AAB)
- Uploads artifacts to GitHub Release

**Required GitHub Secrets** (for signed release builds):

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | Base64-encoded `.keystore` file |
| `KEYSTORE_PASSWORD` | Keystore password |
| `KEY_ALIAS` | Key alias name |
| `KEY_PASSWORD` | Key password |

---

## Platform Notes

### Android
- **Min SDK**: 23 (Android 6.0)
- **Target SDK**: 35 (Android 16)
- **Permissions**: `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `SCHEDULE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`
- **Auto-start**: MIUI / HyperOS users must manually enable auto-start, background pop-up, and lock-screen display permissions

### iOS
- Requires macOS for building
- Notification permissions must be granted at runtime

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Ensure `flutter analyze` and `flutter test` pass
4. Commit your changes
5. Push to your fork and open a Pull Request

---

## License

MIT
