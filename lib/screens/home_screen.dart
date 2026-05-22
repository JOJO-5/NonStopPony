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
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: kBrandBrown.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: kSpace2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
