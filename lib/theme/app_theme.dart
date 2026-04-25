import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';

export 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static CupertinoThemeData get cupertinoTheme {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.bg,
      barBackgroundColor: Color(0xE6030712),
      textTheme: CupertinoTextThemeData(
        primaryColor: AppColors.primary,
        textStyle: TextStyle(
          fontFamily: '.SF Pro Display',
          color: AppColors.text,
          fontSize: 16,
        ),
        navTitleTextStyle: TextStyle(
          fontFamily: '.SF Pro Display',
          color: AppColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontFamily: '.SF Pro Display',
          color: AppColors.text,
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
        tabLabelTextStyle: TextStyle(
          fontFamily: '.SF Pro Display',
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Material fallback for widgets that need it
  static ThemeData get materialTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.card,
        error: AppColors.danger,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
    );
  }
}

// ─── Reusable decorations ───

class AppDecorations {
  AppDecorations._();

  static BoxDecoration get card => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      );

  static BoxDecoration get cardElevated => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration gradientButton(LinearGradient gradient) => BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      );
}

// ─── Text styles ───

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.text,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.text,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    fontFamily: 'SF Mono',
    color: AppColors.primary,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: 'SF Mono',
    color: AppColors.text,
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
    letterSpacing: 0.5,
  );
}
