// ============================================================
// SPLASH SCREEN — Écran de démarrage ENIAD
// ============================================================
// Affiche le logo de l'école pendant 2 secondes
// Vérifie si l'utilisateur est connecté :
//  - Connecté → Dashboard de son rôle
//  - Pas connecté → Login
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/storage_service.dart';
import '../../core/constants/app_constants.dart';
import 'login_screen.dart';
import '../admin/admin_dashboard.dart';
import '../etudiant/etudiant_dashboard.dart';
import '../professeur/professeur_dashboard.dart';
import '../../core/services/api_service.dart';
import '../../core/services/fcm_service.dart';
import '../etudiant/onboarding/add_photo_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  // ── Vérifie si l'utilisateur est déjà connecté ─────────────
  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final isLoggedIn = await StorageService.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      final role = await StorageService.getRole();
      final userId = await StorageService.getUserId();

      if (!mounted) return;

      // ── Réabonne aux topics FCM ──────────────────────────
      await _refreshFCMSubscriptions(role, userId);

      if (!mounted) return;

      if (role == 'admin') {
        _goToAdmin();
      } else if (role == 'etudiant') {
        // Vérifie si l'étudiant a une photo
        final hasPhoto = await ApiService.hasPhoto();
        if (!mounted) return;
        if (hasPhoto) {
          _goToEtudiant();
        } else {
          _goToAddPhoto();
        }
      } else if (role == 'professeur') {
        _goToProf();
      } else {
        _goToLogin();
      }
    }
    else{
      _goToLogin();
    }
  }

  // ── Réabonne aux topics FCM ─────────────────────────────────
  Future<void> _refreshFCMSubscriptions(String? role, String? userId) async {
    try {
      if (role == 'etudiant') {
        final modules = await ApiService.getMyModules();
        final moduleIds = modules.map((m) => m['id'] as String).toList();
        await FCMService.subscribeToModules(moduleIds);
      } else if (role == 'professeur' && userId != null) {
        await FCMService.subscribeToProfTopic(userId);
      }
    } catch (e) {
      print('Erreur refresh FCM: $e');
    }
  }

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  void _goToAdmin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AdminDashboard(),
      ),
    );
  }

  void _goToEtudiant() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const EtudiantDashboard(),
      ),
    );
  }

  void _goToProf() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const ProfesseurDashboard(),
      ),
    );
  }

  void _goToAddPhoto() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AddPhotoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Logo / Icône école ───────────────────────────
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school,
                  size: 70,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: AppTheme.spaceXLarge),

              // ── Nom de l'école ───────────────────────────────
              const Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 6,
                ),
              ),

              const SizedBox(height: AppTheme.spaceSmall),

              // ── Description ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      AppConstants.appFullName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppTheme.textMedium,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXSmall),
                    Text(
                      AppConstants.appCity,
                      style: TextStyle(
                        fontSize: AppTheme.textSmall,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Loader ───────────────────────────────────────
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),

              const SizedBox(height: AppTheme.spaceLarge),

              // ── Slogan ───────────────────────────────────────
              Text(
                AppConstants.appSlogan,
                style: TextStyle(
                  fontSize: AppTheme.textSmall,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),

              const SizedBox(height: AppTheme.spaceXLarge),
            ],
          ),
        ),
      ),
    );
  }
}