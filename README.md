# 战马闹钟 🐎

一个智能闹钟 App，专为 **单双休** 工作制设计。

## 功能

- **闹钟** — 支持单休、双休、自定义重复，智能识别单双周
- **单双休引擎** — 从 2024-01-01 起自动计算周奇偶，支持手动覆盖
- **法定节假日** — 自动同步国家法定节假日，假期不响、补班照响
- **计时器** — 倒计时，支持后台运行和锁屏响铃
- **秒表** — 计次计时
- **日程** — 每月视图，可手动切换单/双休周
- **铃声选择** — 系统铃声 + 自定义铃声

## 技术栈

Flutter 3.35 · Dart 3.9 · Provider · sqflite · flutter_local_notifications

## 构建

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

## 兼容性

最低 Android 6.0，目标 Android 16。MIUI/HyperOS 需手动开启「自启动」「后台弹出界面」「锁屏显示」权限。
