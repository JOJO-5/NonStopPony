# 战马闹钟 🐎

专为**单双周**工作制打造的智能闹钟，支持法定节假日自动跳过。

---

## 功能

### ⏰ 闹钟
- **重复模式**：单次、每天、工作日、周末、自定义
- **单双周（单双休）**：基于起始日期自动判断当前是单周还是双周，闹钟只在对应类型的周生效
- **周类型手动切换**：可在 App 内强制指定单周或双周
- **节假日感知**：自动跳过法定节假日，在补班日照常响铃
- **自定义铃声**：支持系统铃声 + 自定义音频

### 🔧 工具
- **计时器**：倒计时，支持后台音频和锁屏响铃
- **秒表**：计次计时，记录分段成绩
- **日程**：月视图，支持手动切换单/双周显示

---

## 技术架构

| 层次 | 技术 |
|------|------|
| 状态管理 | Provider (ChangeNotifier) |
| 本地存储 | sqflite |
| 通知推送 | flutter_local_notifications |
| 日期处理 | intl |

### 目录结构

```
lib/
├── models/
│   ├── alarm_info.dart       # 闹钟模型 + RepeatType 枚举
│   └── week_schedule.dart    # 单双周类型 + 奇偶判断
├── providers/
│   ├── alarm_provider.dart        # 闹钟增删改查 + 调度
│   └── schedule_provider.dart     # 周类型联动覆盖逻辑
├── services/
│   ├── alarm_storage_service.dart      # SQLite 持久化
│   ├── alarm_notification_service.dart # 通知生命周期
│   └── alarm_scheduler_service.dart    # 下次响铃时间计算 + 节假日逻辑
├── screens/                  # 闹钟列表、添加/编辑表单、响铃全屏界面
├── widgets/                  # 闹钟卡片、重复选择器等组件
└── utils/
    └── date_utils.dart       # shouldRingOnDate、周奇偶、节假日查询
```

---

## 快速开始

### 环境要求
- Flutter SDK 3.9+ (stable)
- Android SDK (minSdkVersion 23 / Android 6.0)
- 发布版本构建需要 Java 17 + 签名 keystore

### 运行

```bash
flutter pub get
flutter run
```

### 测试

```bash
flutter analyze    # 静态分析 + 类型检查
flutter test        # 全部测试
```

### 构建

```bash
# 调试 APK
flutter build apk --debug

# 发布 APK（按 ABI 拆分）
flutter build apk --release --split-per-abi

# Web
flutter build web

# iOS（需要 macOS）
flutter build ios --no-codesign
```

---

## CI / 发布

推送到 `master` 分支自动触发：
1. `flutter analyze` — 静态分析
2. `flutter test` — 全部测试
3. `flutter build apk` — Android 调试 APK
4. `flutter build web` — Web 构建

打标签 `v*` 额外触发：
- 构建签名发布 APK（按 ABI 拆分）+ App Bundle (AAB)
- 自动上传到 GitHub Release

**需要的 GitHub Secrets**（签名发布用）：

| Secret | 说明 |
|--------|------|
| `KEYSTORE_BASE64` | Base64 编码的 `.keystore` 文件 |
| `KEYSTORE_PASSWORD` | Keystore 密码 |
| `KEY_ALIAS` | Key 别名 |
| `KEY_PASSWORD` | Key 密码 |

---

## 平台说明

### Android
- **最低版本**：23 (Android 6.0)
- **目标版本**：35 (Android 16)
- **权限**：`RECEIVE_BOOT_COMPLETED`、`VIBRATE`、`SCHEDULE_EXACT_ALARM`、`USE_FULL_SCREEN_INTENT`
- **自启动**：MIUI / HyperOS 用户需手动开启「自启动」「后台弹出界面」「锁屏显示」权限

### iOS
- 需要 macOS 进行构建
- 通知权限需在运行时申请

---

## 贡献

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/xxx`)
3. 确保 `flutter analyze` 和 `flutter test` 通过
4. 提交代码
5. Push 到你的 Fork 并发起 Pull Request

---

## 开源协议

MIT
