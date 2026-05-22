import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/schedule_provider.dart';
import '../widgets/week_schedule_calendar.dart';

/// Schedule screen showing a monthly calendar with 单休/双休 week types.
///
/// Features:
/// - Month navigation with left/right arrows
/// - Weekly calendar grid showing week type badges
/// - Legend explaining color meanings
/// - Tap any week row to toggle its type
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late int _currentYear;
  late int _currentMonth;

  static const _orange = Color(0xFFE8936A);
  static const _green = Color(0xFF4CAF50);
  static const _scaffoldBg = Color(0xFFFDF8F3);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentYear = now.year;
    _currentMonth = now.month;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        title: const Text('日程'),
        backgroundColor: _scaffoldBg,
        elevation: 0,
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          if (!provider.loaded) {
            provider.loadOverrides();
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildMonthNavigation(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: WeekScheduleCalendar(
                    year: _currentYear,
                    month: _currentMonth,
                    provider: provider,
                  ),
                ),
              ),
              _buildLegend(),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _goToPreviousMonth,
            icon: const Icon(Icons.chevron_left, size: 28),
            color: const Color(0xFF3D2C2C),
          ),
          const SizedBox(width: 8),
          Text(
            '$_currentYear年$_currentMonth月',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D2C2C),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _goToNextMonth,
            icon: const Icon(Icons.chevron_right, size: 28),
            color: const Color(0xFF3D2C2C),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _legendItem(color: _orange, label: '单休：周六班，周日休'),
            const SizedBox(height: 6),
            _legendItem(color: _green, label: '双休：周六日都休'),
            const SizedBox(height: 8),
            const Text(
              '点击周行可切换单休/双休类型',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF616161),
          ),
        ),
      ],
    );
  }

  void _goToPreviousMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
  }

  void _goToNextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
  }
}