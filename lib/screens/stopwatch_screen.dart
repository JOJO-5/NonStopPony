import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stopwatch_provider.dart';
import '../app.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDuration(Duration d) {
    final cents = (d.inMilliseconds ~/ 10) % 100;
    final seconds = d.inSeconds % 60;
    final minutes = d.inMinutes % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${cents.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StopwatchProvider>(
      builder: (context, provider, _) {
        final laps = provider.laps;
        final displayLaps = laps.length > 10 ? laps.sublist(laps.length - 10) : laps;
        final bestIndex = provider.bestLapIndex;

        return Scaffold(
          backgroundColor: kBrandWarmBg,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _TimeDisplay(formattedTime: provider.formattedTime),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _LapList(
                      laps: displayLaps,
                      bestLapIndex: bestIndex,
                      totalLapCount: laps.length,
                      scrollController: _scrollController,
                      formatDuration: _formatDuration,
                      isIdle: provider.state == StopwatchState.idle,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ControlButtons(provider: provider, onLap: _scrollToBottom),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimeDisplay extends StatelessWidget {
  final String formattedTime;

  const _TimeDisplay({required this.formattedTime});

  @override
  Widget build(BuildContext context) {
    return Text(
      formattedTime,
      style: const TextStyle(
        fontSize: 64,
        fontWeight: FontWeight.w700,
        fontFeatures: [FontFeature.tabularFigures()],
        color: kBrandTextPrimary,
        letterSpacing: 2,
      ),
    );
  }
}

class _LapList extends StatelessWidget {
  final List<Lap> laps;
  final int bestLapIndex;
  final int totalLapCount;
  final ScrollController scrollController;
  final String Function(Duration) formatDuration;
  final bool isIdle;

  const _LapList({
    required this.laps,
    required this.bestLapIndex,
    required this.totalLapCount,
    required this.scrollController,
    required this.formatDuration,
    required this.isIdle,
  });

  @override
  Widget build(BuildContext context) {
    if (laps.isEmpty) {
      return Center(
        child: Text(
          isIdle ? '点击「开始」开始计时' : '计次记录将显示在这里',
          style: const TextStyle(
            fontSize: 14,
            color: kBrandTextSecondary,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kBrandSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBrandOutlineVariant, width: 0.5),
        boxShadow: kShadowSoft,
      ),
      child: ListView.separated(
        controller: scrollController,
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: laps.length,
        separatorBuilder: (_, i) => const Divider(height: 1, color: kBrandOutlineVariant),
        itemBuilder: (context, index) {
          final lap = laps[index];
          final isEven = index.isEven;
          final isBest = lap.index - 1 == bestLapIndex && laps.length > 1;

          return Container(
            color: isEven ? Colors.white : kBrandSurfaceAlt,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    '计次 ${lap.index}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isBest ? kBrandCopper : kBrandTextSecondary,
                      fontWeight: isBest ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    formatDuration(lap.lapTime),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: isBest ? kBrandCopper : kBrandTextPrimary,
                      fontWeight: isBest ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    formatDuration(lap.elapsed),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: kBrandTextSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ControlButtons extends StatelessWidget {
  final StopwatchProvider provider;
  final VoidCallback onLap;

  const _ControlButtons({required this.provider, required this.onLap});

  @override
  Widget build(BuildContext context) {
    switch (provider.state) {
      case StopwatchState.idle:
        return _StartButton(onPressed: provider.start);
      case StopwatchState.running:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CircleButton(
              label: '计次',
              icon: Icons.flag,
              backgroundColor: kBrandOutline,
              foregroundColor: kBrandTextSecondary,
              onPressed: () {
                provider.lap();
                onLap();
              },
            ),
            _CircleButton(
              label: '停止',
              icon: Icons.stop,
              backgroundColor: kSemanticError,
              foregroundColor: Colors.white,
              onPressed: provider.pause,
            ),
          ],
        );
      case StopwatchState.paused:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _CircleButton(
              label: '继续',
              icon: Icons.play_arrow,
              backgroundColor: kBrandCopper,
              foregroundColor: Colors.white,
              onPressed: provider.start,
            ),
            _CircleButton(
              label: '重置',
              icon: Icons.refresh,
              backgroundColor: kBrandOutline,
              foregroundColor: kBrandTextSecondary,
              onPressed: provider.reset,
            ),
          ],
        );
    }
  }
}

class _StartButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StartButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return _RoundButton(
      icon: Icons.play_arrow_rounded,
      size: 84,
      iconSize: 40,
      gradient: kCopperGradient,
      glow: true,
      onTap: onPressed,
    );
  }
}

class _CircleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onPressed;

  const _CircleButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isCopper = backgroundColor == kBrandCopper;
    final isPlain = backgroundColor == Colors.white;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: icon,
          size: 64,
          iconSize: 28,
          gradient: isCopper ? kCopperGradient : null,
          color: isCopper ? null : backgroundColor,
          foreground: foregroundColor,
          outlined: isPlain,
          glow: isCopper,
          onTap: onPressed,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: kBrandTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Shared circular action button — gradient primary or flat secondary,
/// with a soft warm shadow. Replaces the old FloatingActionButton hack.
class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final LinearGradient? gradient;
  final Color? color;
  final Color foreground;
  final bool outlined;
  final bool glow;

  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.size = 64,
    this.iconSize = 28,
    this.gradient,
    this.color,
    this.foreground = Colors.white,
    this.outlined = false,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: gradient,
          color: gradient == null ? (outlined ? kBrandSurface : color) : null,
          border: outlined
              ? Border.all(color: kBrandCopper.withValues(alpha: 0.5), width: 1.5)
              : null,
          boxShadow: glow ? kShadowGlow : kShadowSoft,
        ),
        child: Icon(icon, size: iconSize, color: foreground),
      ),
    );
  }
}