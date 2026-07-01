# 更新日志

## 2.0.0+2002 (2026-07-01)

### 🐛 Bug 修复
- **自启失效修复**:手机重启 / 锁屏启动后闹钟不响
  - AndroidManifest.xml:给 `BootReceiver` / `AlarmReceiver` / `TimerReceiver` / `AlarmRingingService` / `TimerRingingService` 加 `android:directBootAware="true"`,确保 `LOCKED_BOOT_COMPLETED` 阶段能被调用(国产 ROM 必备)
  - BootReceiver 同步直接打开 sqflite `alarm_clock.db`,用 AlarmManager 兜底注册最近一个要响的闹钟(无需 SCHEDULE_EXACT_ALARM 用户授权,无需 FlutterEngine 启动)
  - 保留原 WorkManager → AlarmRescheduleWorker → Dart 路径,两条路并行:原生路径保底 + Dart 路径完整重排

### 🔧 工程改进
- CI:新增 `release-android` job,打 `v*` tag 时自动出签名 APK + GitHub Release
- CI:`build.gradle.kts` 改用 `signingConfigs.release` 读取 `key.properties`,本地无 keystore 时自动 fallback 到 debug 签名
