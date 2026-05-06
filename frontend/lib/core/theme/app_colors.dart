// ============================================================
// COULEURS DE L'APPLICATION ENIAD
// ============================================================

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Couleur principale ENIAD (Terracotta) ─────────────────
  static const Color primary = Color(0xFFC26B4F);
  static const Color primaryDark = Color(0xFFA85638);
  static const Color primaryLight = Color(0xFFF5E4DD);

  // ── Couleurs par rôle ─────────────────────────────────────
  static const Color admin = Color(0xFF4B4ACF);
  static const Color adminLight = Color(0xFFEEEDFE);

  static const Color etudiant = Color(0xFF1D9E75);
  static const Color etudiantLight = Color(0xFFE1F5EE);

  static const Color professeur = Color(0xFF185FA5);
  static const Color professeurLight = Color(0xFFE6F1FB);

  // ── Couleurs sémantiques ──────────────────────────────────
  static const Color success = Color(0xFF1D9E75);
  static const Color successLight = Color(0xFFE1F5EE);

  static const Color error = Color(0xFFA32D2D);
  static const Color errorLight = Color(0xFFFCEBEB);

  static const Color warning = Color(0xFFBA7517);
  static const Color warningLight = Color(0xFFFAEEDA);

  static const Color info = Color(0xFF185FA5);
  static const Color infoLight = Color(0xFFE6F1FB);

  // ── Couleurs neutres ──────────────────────────────────────
  static const Color background = Color(0xFFFAF6F2);
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGrey = Color(0xFF888888);
  static const Color textLight = Color(0xFFB0B0B0);

  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color cardShadow = Color(0x14000000);

  // ── Helper pour obtenir la couleur d'un rôle ──────────────
  static Color forRole(String role) {
    switch (role) {
      case 'admin':
        return admin;
      case 'professeur':
        return professeur;
      case 'etudiant':
        return etudiant;
      default:
        return primary;
    }
  }

  static Color forRoleLight(String role) {
    switch (role) {
      case 'admin':
        return adminLight;
      case 'professeur':
        return professeurLight;
      case 'etudiant':
        return etudiantLight;
      default:
        return primaryLight;
    }
  }
}