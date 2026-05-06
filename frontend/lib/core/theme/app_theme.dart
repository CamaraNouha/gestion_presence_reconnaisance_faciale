// ============================================================
// THÈME GLOBAL ENIAD
// ============================================================

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // ── Tailles de texte ──────────────────────────────────────
  static const double textXSmall = 11;
  static const double textSmall = 12;
  static const double textMedium = 14;
  static const double textLarge = 16;
  static const double textXLarge = 20;
  static const double textHuge = 28;

  // ── Espacements standard ──────────────────────────────────
  static const double spaceXSmall = 4;
  static const double spaceSmall = 8;
  static const double spaceMedium = 12;
  static const double spaceLarge = 16;
  static const double spaceXLarge = 24;
  static const double spaceHuge = 32;

  // ── Border radius ─────────────────────────────────────────
  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 24;
  static const double radiusRound = 100;

  // ── Theme principal ───────────────────────────────────────
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',

        // Couleurs
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        scaffoldBackgroundColor: AppColors.background,

        // AppBar
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          titleTextStyle: TextStyle(
            fontSize: textLarge,
            fontWeight: FontWeight.w600,
            color: AppColors.white,
            fontFamily: 'Roboto',
          ),
          iconTheme: IconThemeData(color: AppColors.white),
        ),

        // Boutons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(
              vertical: spaceLarge,
              horizontal: spaceXLarge,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            textStyle: const TextStyle(
              fontSize: textMedium,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Champs texte
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: spaceLarge,
            vertical: spaceLarge,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          hintStyle: const TextStyle(
            color: AppColors.textGrey,
            fontSize: textMedium,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textGrey,
            fontSize: textMedium,
          ),
        ),

        // Cards
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
        ),

        // Dividers
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // Snack bar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
        ),
      );
}