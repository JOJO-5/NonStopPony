import 'package:flutter/material.dart';
import '../app.dart';

/// About page with brand story and easter egg.
/// Tap the logo 7 times to trigger the easter egg!
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with TickerProviderStateMixin {
  int _tapCount = 0;
  bool _easterEggActivated = false;
  late AnimationController _pulseController;
  late AnimationController _gallopController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _gallopAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    _gallopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _gallopAnimation = CurvedAnimation(
      parent: _gallopController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _gallopController.dispose();
    super.dispose();
  }

  void _onLogoTap() {
    if (_easterEggActivated) return;
    _tapCount++;
    if (_tapCount >= 7) {
      setState(() => _easterEggActivated = true);
      _gallopController.forward();
    } else if (_tapCount >= 4) {
      // Small feedback
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('再点 ${7 - _tapCount} 次唤醒战马…'),
          duration: const Duration(seconds: 1),
          backgroundColor: kBrandCopper,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandWarmBg,
      appBar: AppBar(
        title: const Text('关于'),
        backgroundColor: kBrandWarmBg,
        foregroundColor: kBrandTextPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: kSpace5),
        child: Column(
          children: [
            const SizedBox(height: kSpace8),
            // Logo with easter egg
            GestureDetector(
              onTap: _onLogoTap,
              child: ScaleTransition(
                scale: _easterEggActivated
                    ? _gallopAnimation
                    : Tween<double>(begin: 1.0, end: 1.05).animate(_pulseAnimation),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: kBrandCopper.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    boxShadow: _easterEggActivated
                        ? [
                            BoxShadow(
                              color: kBrandCopper.withValues(alpha: 0.4),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icon.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: kSpace5),
            const Text(
              '战马闹钟',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: kBrandTextPrimary,
              ),
            ),
            const SizedBox(height: kSpace1),
            const Text(
              'v1.0.0',
              style: TextStyle(fontSize: 14, color: kBrandTextSecondary),
            ),
            const SizedBox(height: kSpace8),

            // Brand story card
            _StoryCard(
              icon: Icons.auto_stories_rounded,
              title: '战马的故事',
              content: '每一匹战马，都有自己的战场。\n\n'
                  '有人在周一到周五冲锋，有人周六还在加班。\n'
                  '法定节假日调休，闹钟却只认周一到周五。\n'
                  '单休的双休的，谁不是在努力奔跑？\n\n'
                  '战马闹钟，懂你的每一周。',
            ),
            const SizedBox(height: kSpace3),

            // Core feature card
            _StoryCard(
              icon: Icons.work_history_rounded,
              title: '为什么做战马闹钟？',
              content: '痛点很简单：\n\n'
                  '❌ 定"工作日"响 → 调休周六上班不响\n'
                  '❌ 定"每天"响 → 休息日被吵醒，炸毛\n'
                  '❌ 单双休轮换 → 每周手动开关闹钟\n\n'
                  '战马闹钟一个设置全搞定：\n'
                  '✅ 智能识别单周/双周\n'
                  '✅ 自动适配调休工作日\n'
                  '✅ 只在该响的时候响',
            ),
            const SizedBox(height: kSpace3),

            // Philosophy card
            _StoryCard(
              icon: Icons.psychology_rounded,
              title: '设计理念',
              content: '闹钟应该是贴心的，不是烦人的。\n\n'
                  '它知道你什么时候上班，\n'
                  '也知道你什么时候该休息。\n'
                  '不多响一次，也不少响一次。',
            ),
            const SizedBox(height: kSpace3),

            // Easter egg reveal
            if (_easterEggActivated) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(kSpace5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      kBrandCopper.withValues(alpha: 0.15),
                      kSemanticSuccess.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(kRadiusLg),
                  border: Border.all(color: kBrandCopper.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🐎',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: kSpace3),
                    const Text(
                      '你唤醒了战马！',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kBrandCopper,
                      ),
                    ),
                    const SizedBox(height: kSpace2),
                    Text(
                      '战马从不迟到。\n'
                      '因为迟到的不是战马，是还没起床的你。\n\n'
                      '「每一个能早起的打工人，\n'
                      '  都是自己的战马。」',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: kBrandTextPrimary.withValues(alpha: 0.8),
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: kSpace3),
            ],

            // Footer
            const SizedBox(height: kSpace6),
            Text(
              '用 ❤️ 为打工人制作',
              style: TextStyle(
                fontSize: 12,
                color: kBrandTextSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: kSpace12),
          ],
        ),
      ),
    );
  }
}

// ── Story card widget ──────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _StoryCard({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace5),
      decoration: BoxDecoration(
        color: kBrandSurface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: kBrandOutlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: kBrandCopper),
              const SizedBox(width: kSpace2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kBrandTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: kBrandTextPrimary.withValues(alpha: 0.85),
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
