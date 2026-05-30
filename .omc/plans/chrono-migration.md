# Chrono → alarm_clock 迁移计划

**状态**: pending approval
**日期**: 2026-05-30
**来源**: chrono (vicolo-dev/chrono, 256 dart 文件) → alarm_clock (33 dart 文件)

---

## 差距总览

| 模块 | chrono | alarm_clock | 状态 |
|------|--------|-------------|------|
| alarm 闹钟 | 49 | 16 | PARTIAL |
| clock 世界时钟 | 12 | 0 | MISSING |
| timer 计时器 | 28 | 7 | PARTIAL |
| stopwatch 秒表 | 9 | 2 | PARTIAL |
| audio 音频 | 6 | 0 | MISSING |
| settings 设置 | 51 | 5 | PARTIAL |
| common 通用 | 129 | 4 | MISSING |
| developer 开发 | 9 | 0 | MISSING |
| l10n 国际化 | 1 | 0 | MISSING |
| navigation 导航 | 15 | 1 | PARTIAL |
| notifications 通知 | 11 | 0 | MISSING |
| system 系统 | 10 | 0 | MISSING |
| theme 主题 | 22 | 3 | PARTIAL |
| widgets 桌面 | 2 | 0 | MISSING |
| icons 图标 | 1 | 0 | MISSING |

---

## 迁移原则

1. **增量移植** — 每次一个功能，移植完编译通过再下一个
2. **保留独有** — 单双休引擎、战马品牌色、中文，绝不破坏
3. **适配不替换** — chrono 用 GetStorage/awesome_notifications，我们保留 sqflite/flutter_local_notifications
4. **最小依赖** — 不新增 pub 包

---

## 实施阶段

### Phase 1: 闹钟挑战集成 (P0)
`lib/widgets/tasks/math_challenge.dart` `lib/widgets/tasks/retype_challenge.dart` 已是死代码，仅需集成。
- [ ] 读取 chrono `sequence_task.dart`，适配创建 `sequence_challenge.dart`
- [ ] 在 `alarm_fullscreen_screen.dart` 集成：根据 `taskType` 显示挑战 widget
- [ ] 在 `add_edit_alarm_screen.dart` 添加任务类型选择器
- [ ] `flutter analyze` 通过

### Phase 2: 计时器拨盘 (P0)
`lib/widgets/dial_duration_picker.dart` 已是死代码，仅需集成。
- [ ] 在 `timer_screen.dart` 添加拨盘/滚轮切换按钮 + `_useDialPicker` 状态
- [ ] `flutter analyze` 通过

### Phase 3: 世界时钟 (P1)
- [ ] 从 chrono 移植 `timezone_card.dart`、`timezone_database.dart`、`default_favorite_cities.dart`
- [ ] 创建 `world_clock_screen.dart`、`search_city_screen.dart`
- [ ] 重写 `models/city.dart` 为可用模型
- [ ] 在 `home_screen.dart` 添加第 6 个 tab
- [ ] `flutter analyze` 通过

### Phase 4: 铃声系统 (P1)
- [ ] 从 chrono 移植 `ringtone_player.dart`（简化适配 MethodChannel）
- [ ] 增强 `ringtone_picker_screen.dart` 支持预览播放
- [ ] `flutter analyze` 通过

### Phase 5: 设置框架 (P2)
- [ ] 创建 `SliderSettingCard`
- [ ] `settings_screen.dart` 用 SettingGroup 分组
- [ ] `flutter analyze` 通过

### Phase 6: 备份恢复 (P2)
- [ ] 创建 `backup_service.dart`，从 `settings_screen.dart` 提取逻辑
- [ ] 添加导入确认对话框、导入后刷新 provider + 重调度
- [ ] `flutter analyze` 通过

### Phase 7: 开发工具 + 日期UI (P3)
- [ ] `developer_screen.dart` 添加 DB 大小、日志导出
- [ ] `add_edit_alarm_screen.dart` 添加 dates/range DatePicker UI
- [ ] `flutter analyze` 通过

### Phase 8: 验证
- [ ] `flutter analyze` 0 errors
- [ ] `flutter test` 通过
- [ ] `flutter build apk --debug` 成功
- [ ] 单双休验证: `grep shouldRingOnDate resolveWeekType singleRest doubleRest`

---

## 不移植项（原因）

| 项 | 理由 |
|----|------|
| Polymorphic AlarmSchedule 类层次 | RepeatType enum + date_utils 已覆盖所有场景 |
| GetStorage 替换 sqflite | 已有 DB v9 迁移，替换风险大无收益 |
| awesome_notifications | 需重写全部 Android native 代码 |
| 22 语言国际化 | 当前仅需中文 |
| 12 套主题 | 战马品牌色是定制的 |
| common/ 129 文件 | 太重，仅移植实际需要的 |
| Navigation 子系统 | 5-tab BottomNavigationBar 够用 |
| Android 桌面小部件 | 需额外 native 开发 |
| Isolate 后台调度 | AlarmSchedulerService 功能正常 |
| Onboarding | 无需求 |

---

## 验收标准

1. 闹钟挑战: math/retype/sequence 可选，正确触发 dismiss
2. 计时器: 滚轮/拨盘可切换，时长同步
3. 世界时钟: 10+ 预设城市，搜索，每秒刷新
4. 铃声: 列表 + 预览播放 + 选择确认
5. 设置: SliderSettingCard + 分组显示
6. 备份: JSON 导出→分享，导入→恢复+重调度
7. 构建: debug APK 成功
8. 回归: 单双休逻辑不受影响
