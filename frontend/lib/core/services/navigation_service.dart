// ============================================================
// NAVIGATION SERVICE — navigation sans BuildContext
// ============================================================
// Permet de naviguer depuis du code non-widget (ex: intercepteur
// Dio) grâce à une clé de navigation globale posée sur MaterialApp.
// ============================================================

import 'package:flutter/material.dart';
import '../../features/auth/login_screen.dart';

class NavigationService {
  NavigationService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Renvoie l'utilisateur vers l'écran de login en vidant la pile.
  /// Utilisé quand la session est définitivement expirée.
  static void goToLogin() {
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}
