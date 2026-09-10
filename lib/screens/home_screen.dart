import 'package:flutter/material.dart';
import 'alarm_list_screen.dart';
import 'schedule_screen.dart';
import 'timer_screen.dart';
import 'stopwatch_screen.dart';
import 'settings_screen.dart';
import '../app.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const _tabs = <_TabEntry>[
    _TabEntry(label: '\u95f9\u949f', icon: Icons.alarm_rounded, activeIcon: Icons.alarm_on_rounded),
    _TabEntry(label: '\u65e5\u7a0b', icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month_rounded),
    _TabEntry(label: '\u8ba1\u65f6', icon: Icons.timer_outlined, activeIcon: Icons.timer_rounded),
    _TabEntry(label: '\u79d2\u8868', icon: Icons.timer_off_outlined, activeIcon: Icons.watch_later_rounded),
    _TabEntry(label: '\u8bbe\u7f6e', icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded),
  ];

  static const _screens = <Widget>[
    AlarmListScreen(),
    ScheduleScreen(),
    TimerScreen(),
    StopwatchScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: kBrandSurface,
          boxShadow: [
            BoxShadow(
              color: Color(0x142D1B0E),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace2, horizontal: kSpace1),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = i == _currentIndex;
                return _NavItem(
                  icon: isActive ? tab.activeIcon : tab.icon,
                  label: tab.label,
                  isActive: isActive,
                  activeColor: colorScheme.primary,
                  inactiveColor: colorScheme.onSurfaceVariant,
                  onTap: () => setState(() => _currentIndex = i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: kMotionBase,
              curve: kCurveOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                gradient: isActive ? kCopperGradientSoft : null,
                borderRadius: BorderRadius.circular(kRadiusPill),
              ),
              child: Icon(
                icon,
                size: 23,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabEntry {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _TabEntry({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
