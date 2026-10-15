import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:magneto_pro/core/constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        surface: AppColors.surface,
        onSurface: AppColors.textMain,
      ),
      scaffoldBackgroundColor: AppColors.bgApp,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: AppColors.textMain,
        displayColor: AppColors.textMain,
      ),
    );
  }
}
