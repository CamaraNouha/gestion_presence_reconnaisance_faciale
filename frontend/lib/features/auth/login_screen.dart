// ============================================================
// LOGIN SCREEN — Connexion ENIAD
// ============================================================
// Connexion par Apogée + Mot de passe
// Le rôle est détecté automatiquement par le backend
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/message_box.dart';
import '../../core/constants/app_constants.dart';
import '../admin/admin_dashboard.dart';
import '../etudiant/etudiant_dashboard.dart';
import '../professeur/professeur_dashboard.dart';
import '../../core/services/fcm_service.dart';
import '../etudiant/onboarding/add_photo_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apogeeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _apogeeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Action de connexion ─────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final response = await ApiService.login(
        apogee: _apogeeCtrl.text.trim(),
        motDePasse: _passwordCtrl.text,
      );

      final token = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      await StorageService.saveAuthData(
        token: token,
        refreshToken: refreshToken,
        userId: user['id'] ?? '',
        role: user['role'] ?? '',
        nom: user['nom'] ?? '',
        prenom: user['prenom'] ?? '',
        email: user['email'] ?? '',
        apogee: user['apogee'] ?? '',
      );

      // ── Abonne aux topics FCM selon le rôle ───────────────
      await _setupFCMSubscriptions(
        role: user['role'],
        userId: user['id'],
      );

      if (!mounted) return;

      MessageBox.show(
        context,
        message: 'Bienvenue ${user['prenom']} !',
        type: MessageType.success,
      );

      _redirectByRole(user['role']);
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Redirection selon le rôle ───────────────────────────────
  Future<void> _redirectByRole(String role) async {
    if (role == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else if (role == 'etudiant') {
      // Vérifie si l'étudiant a une photo
      final hasPhoto = await ApiService.hasPhoto();
      if (!mounted) return;

      if (hasPhoto) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EtudiantDashboard()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AddPhotoScreen()),
        );
      }
    } else if (role == 'professeur') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfesseurDashboard()),
      );
    }
  }

  // ── Abonne aux topics FCM selon le rôle ───────────────────
  Future<void> _setupFCMSubscriptions({
    required String role,
    required String userId,
  }) async {
    try {
      if (role == 'etudiant') {
        // L'étudiant s'abonne aux topics de ses modules
        final modules = await ApiService.getMyModules();
        final moduleIds = modules
            .map((m) => m['id'] as String)
            .toList();

        await FCMService.subscribeToModules(moduleIds);
        print('✅ Étudiant abonné à ${moduleIds.length} modules');
      } else if (role == 'professeur') {
        // Le prof s'abonne à son topic perso pour les stats
        await FCMService.subscribeToProfTopic(userId);
        print('✅ Prof abonné à son topic personnel');
      }
    } catch (e) {
      print('❌ Erreur abonnements FCM: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Header décoratif terracotta
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // Logo
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 50,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceMedium),

                    const Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceXSmall),

                    Text(
                      AppConstants.appSlogan,
                      style: TextStyle(
                        fontSize: AppTheme.textSmall,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Carte de connexion
                    Container(
                      padding:
                          const EdgeInsets.all(AppTheme.spaceXLarge),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Connexion',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),

                            const SizedBox(height: AppTheme.spaceXSmall),

                            const Text(
                              'Entrez vos identifiants',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: AppTheme.textMedium,
                                color: AppColors.textGrey,
                              ),
                            ),

                            const SizedBox(height: AppTheme.spaceXLarge),

                            // Apogée
                            AppTextField(
                              controller: _apogeeCtrl,
                              label: 'Numéro Apogée',
                              hint: 'Votre identifiant',
                              icon: Icons.badge_outlined,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Apogée requis';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppTheme.spaceLarge),

                            // Mot de passe
                            AppTextField(
                              controller: _passwordCtrl,
                              label: 'Mot de passe',
                              hint: 'Votre mot de passe',
                              icon: Icons.lock_outline,
                              obscureText: !_showPassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.textGrey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Mot de passe requis';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppTheme.spaceXLarge),

                            // Bouton connexion
                            AppButton(
                              text: 'Se connecter',
                              icon: Icons.login,
                              loading: _loading,
                              onPressed: _login,
                            ),

                            const SizedBox(height: AppTheme.spaceLarge),

                            // Info
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Votre rôle est détecté automatiquement',
                                      style: TextStyle(
                                        fontSize: AppTheme.textXSmall,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceXLarge),

                    const Text(
                      '© 2025 ${AppConstants.appName} - ${AppConstants.appCity}',
                      style:  TextStyle(
                        fontSize: AppTheme.textXSmall,
                        color: AppColors.textGrey,
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceLarge),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}