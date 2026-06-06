import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/alarm_fullscreen_screen.dart';
import 'screens/timer_fullscreen_screen.dart';
import 'services/alarm_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 战马闹钟 · Design System
// ─────────────────────────────────────────────────────────────────────────────

// Core brand colors
const kBrandCopper = Color(0xFFD4794A);
const kBrandCopperDeep = Color(0xFFB85E32);
const kBrandBrown = Color(0xFF2D1B0E);
const kBrandWarmBg = Color(0xFFF9F5F0);
const kBrandSurface = Color(0xFFFFFFFF);
const kBrandSurfaceAlt = Color(0xFFF3EFEA);
const kBrandTextPrimary = Color(0xFF2D1B0E);
const kBrandTextSecondary = Color(0xFF8E7B6A);
const kBrandOutline = Color(0xFFD4C8B8);
const kBrandOutlineVariant = Color(0xFFEAE0D5);

// Semantic
const kSemanticSuccess = Color(0xFF4CAF50);
const kSemanticError = Color(0xFFE85A5A);
const kSemanticWarning = Color(0xFFF59E0B);

// Spacing scale (8px grid)
const kSpace1 = 4.0;
const kSpace2 = 8.0;
const kSpace3 = 12.0;
const kSpace4 = 16.0;
const kSpace5 = 20.0;
const kSpace6 = 24.0;
const kSpace8 = 32.0;
const kSpace10 = 40.0;
const kSpace12 = 48.0;

// Radii
const kRadiusSm = 10.0;
const kRadiusMd = 16.0;
const kRadiusLg = 20.0;
const kRadiusXl = 24.0;

class AlarmClockApp extends StatelessWidget {
  const AlarmClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: kBrandCopper,
      brightness: Brightness.light,
      primary: kBrandCopper,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFEDE0),
      onPrimaryContainer: kBrandCopperDeep,
      secondary: const Color(0xFF8E7B6A),
      onSecondary: Colors.white,
      surface: kBrandSurface,
      surfaceContainerLowest: kBrandWarmBg,
      surfaceContainerLow: const Color(0xFFF3EFEA),
      onSurface: kBrandTextPrimary,
      onSurfaceVariant: kBrandTextSecondary,
      outline: kBrandOutline,
      outlineVariant: kBrandOutlineVariant,
      error: kSemanticError,
    );

    return MaterialApp(
      title: '\u6218\u9a6c\u95f9\u949f',
      debugShowCheckedModeBanner: false,
      navigatorKey: alarmNavigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN')],
      theme: baseTheme.copyWith(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: kBrandWarmBg,
        textTheme: GoogleFonts.notoSansScTextTheme(baseTheme.textTheme).copyWith(
          headlineLarge: GoogleFonts.notoSansSc(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: kBrandTextPrimary,
          ),
          headlineMedium: GoogleFonts.notoSansSc(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: kBrandTextPrimary,
          ),
          titleLarge: GoogleFonts.notoSansSc(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kBrandTextPrimary,
          ),
          titleMedium: GoogleFonts.notoSansSc(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: kBrandTextPrimary,
          ),
          bodyLarge: GoogleFonts.notoSansSc(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: kBrandTextPrimary,
          ),
          bodyMedium: GoogleFonts.notoSansSc(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: kBrandTextSecondary,
          ),
          bodySmall: GoogleFonts.notoSansSc(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: kBrandTextSecondary,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: kBrandWarmBg,
          foregroundColor: kBrandTextPrimary,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          centerTitle: true,
          titleTextStyle: GoogleFonts.notoSansSc(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: kBrandTextPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          color: kBrandSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg),
          ),
          margin: EdgeInsets.zero,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: kBrandCopper,
          unselectedItemColor: const Color(0xFFB8A898),
          type: BottomNavigationBarType.fixed,
          backgroundColor: kBrandSurface,
          elevation: 1,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kBrandCopper,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadiusMd),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      routes: {
        '/alarm_ringing': (ctx) {
          final args = ModalRoute.of(ctx)!.settings.arguments
              as Map<String, dynamic>? ?? {};
          return AlarmFullScreenScreen(
            alarmId: (args['alarmId'] as int?) ?? -1,
            label: (args['label'] as String?) ?? '\u6218\u9a6c\u95f9\u949f',
          );
        },
        '/timer_ringing': (ctx) => const TimerFullScreenScreen(),
      },
      home: const HomeScreen(),
    );
  }
}
