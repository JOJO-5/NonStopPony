# 战马闹钟 - 长期记忆

## 项目概况
- Flutter Android 闹钟应用，项目路径：`D:\mengfanliuFile\dev\clound\alarm_clock`
- 目标设备：小米14 (ADB: 586bb571)，Android 14
- 品牌：战马闹钟，核心卖点：智能单双休闹钟

## 技术架构
- Flutter + Kotlin 混合架构
- MethodChannel：`alarm_ring`, `alarm_scheduler`, `alarm_fire`, `boot_receiver`, `settings`, `ringtone`, `timer_background`, `timer_fire`
- Android AlarmManager 精确调度（替代 zonedSchedule）
- Foreground Service (AlarmRingingService + TimerRingingService) + MediaPlayer + Vibrator
- SQLite DB：当前版本 v4（alarms + week_schedule + holiday_cache 表）

## 核心功能
- 单双休智能编排：链式联动算法，手动切换某周后后续周自动推算
- 法定节假日同步：timor.tech API，本地 SQLite 缓存
- 铃声选择：全屏页面，分类显示系统铃声+自定义，支持试听
- 锁屏全屏闹钟提醒 + 动态钟表动画
- 锁屏全屏计时器提醒 + 动态钟表动画（与闹钟一致）
- 上划关闭手势（闹钟 + 计时器全屏界面）
- 渐入页面切换动画（FadeTransition）

## 开发约定
- ADB 完整路径：`C:\Users\JOJO\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- Flutter analyze 零错误才编译
- DB 版本迭代必须写 onUpgrade 迁移
- 页面切换统一用 PageRouteBuilder + FadeTransition
- AndroidManifest.xml 必须显式声明 INTERNET 权限（debug/profile 有但 main 没有）
