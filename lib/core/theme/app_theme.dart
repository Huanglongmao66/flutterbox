// 主题，对应原项目 res/values/colors.xml + styles.xml
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 主色
  static const Color primary = Color(0xFF6200EE);
  static const Color primaryDark = Color(0xFF3700B3);
  static const Color accent = Color(0xFF03DAC5);
  static const Color focusOrange = Color(0xFFCE7900);
  static const Color blue = Color(0xFF1890FF);
  static const Color orange = Color(0xFFFF6600);
  static const Color green = Color(0xFF00FF0A);
  static const Color lightGreen = Color(0xFFCBF46A);
  static const Color cyan = Color(0xFF0CADE2);
  static const Color pink = Color(0xFFFF0057);

  // 背景
  static const Color background = Color(0xFF1D202A);
  static const Color surface = Color(0xFF23262E);
  static const Color panel = Color(0xFF353744);
  static const Color panelLight = Color(0xFF3D3D3D);
  // 便捷别名
  static const Color card = panel;
  static const Color divider = Color(0x33FFFFFF);

  // 文字
  static const Color textPrimary = Color(0xFFFFFAE0);
  static const Color textSecondary = Color(0xCCFFFFFF);
  static const Color textHint = Color(0x80FFFFFF);
  static const Color text = textPrimary;

  // 对话框
  static const Color dialogBg = Color(0xD91D202A);
  static const Color dialogPanelStroke = Color(0x33FFFFFF);
  static const Color dialogControlBg = Color(0x80353744);
  static const Color dialogControlBgFocused = Color(0xCC1890FF);
  static const Color dialogControlStrokeFocused = Color(0xCC02F8E1);

  // 焦点
  static const Color focusBorder = Color(0xFF02F8E1);
  static const Color focusOverlay = Color(0x66FFFFFF);
  static const Color selectedOverlay = Color(0x66000000);
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      cardColor: AppColors.panel,
      dividerColor: const Color(0x33FFFFFF),
      hintColor: AppColors.textHint,
      focusColor: AppColors.focusOverlay,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
