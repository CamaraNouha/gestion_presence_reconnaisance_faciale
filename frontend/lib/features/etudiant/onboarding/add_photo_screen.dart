// ============================================================
// AJOUTER MA PHOTO — Première connexion étudiant
// ============================================================
// Cet écran est OBLIGATOIRE si l'étudiant n'a pas de photo
// (créé en bloc par l'admin sans photo)
// Bloque l'accès au dashboard tant que la photo n'est pas ajoutée
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/message_box.dart';
import '../etudiant_dashboard.dart';
import '../../auth/login_screen.dart';

class AddPhotoScreen extends StatefulWidget {
  const AddPhotoScreen({super.key});

  @override
  State<AddPhotoScreen> createState() => _AddPhotoScreenState();
}

class _AddPhotoScreenState extends State<AddPhotoScreen> {
  File? _photo;
  bool _loading = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    _userName = await StorageService.getFullName();
    if (mounted) setState(() {});
  }

  // ── Sélection photo ───────────────────────────────────────
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Sélectionner une photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: AppColors.etudiant,
                size: 32,
              ),
              title: const Text('Prendre une photo'),
              subtitle: const Text('Selfie en direct'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.etudiant,
                size: 32,
              ),
              title: const Text('Choisir depuis la galerie'),
              subtitle: const Text('Photo existante'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.front,
    );

    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  // ── Upload de la photo ────────────────────────────────────
  Future<void> _uploadPhoto() async {
    if (_photo == null) return;

    setState(() => _loading = true);

    try {
      await ApiService.uploadMyPhoto(_photo!.path);

      if (!mounted) return;

      MessageBox.show(
        context,
        message: 'Photo enregistrée avec succès',
        type: MessageType.success,
      );

      // Va au dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const EtudiantDashboard(),
        ),
      );
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

  // ── Logout (si l'étudiant ne veut pas) ────────────────────
  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text(
          'Vous devez ajouter votre photo pour utiliser l\'application.\n\n'
          'Voulez-vous vous déconnecter ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await StorageService.clearAll();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Empêche le retour arrière
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ── Header vert ─────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.etudiant, Color(0xFF2BB585)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Bouton logout (si l'étudiant ne veut pas)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _logout,
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Quitter',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Icône
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.face_outlined,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spaceLarge),

                      const Text(
                        'Bienvenue !',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        _userName,
                        style: TextStyle(
                          fontSize: AppTheme.textMedium,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spaceXLarge),

                // ── Message ───────────────────────────────────
                const Padding(
                  padding:  EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLarge),
                  child: Column(
                    children: [
                       Text(
                        'Ajoutez votre photo',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                       SizedBox(height: 8),
                       Text(
                        'Cette photo sera utilisée pour la reconnaissance faciale lors du pointage de présence.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppTheme.textMedium,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spaceXLarge),

                // ── Zone photo ────────────────────────────────
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: _photo != null
                          ? Colors.transparent
                          : AppColors.etudiantLight,
                      borderRadius: BorderRadius.circular(110),
                      border: Border.all(
                        color: AppColors.etudiant,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.etudiant.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: _photo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(110),
                            child: Image.file(
                              _photo!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                size: 60,
                                color: AppColors.etudiant,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tape ici pour\najouter une photo',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: AppTheme.textMedium,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.etudiant,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                if (_photo != null) ...[
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: AppColors.etudiant,
                    ),
                    label: const Text(
                      'Changer la photo',
                      style: TextStyle(color: AppColors.etudiant),
                    ),
                  ),
                ],

                const SizedBox(height: AppTheme.spaceXLarge),

                // ── Conseils ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLarge),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Conseils pour une bonne photo',
                              style: TextStyle(
                                fontSize: AppTheme.textMedium,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          '• Visage bien visible et centré\n'
                          '• Bonne luminosité\n'
                          '• Pas de masque ni de lunettes de soleil\n'
                          '• Regardez droit devant',
                          style: TextStyle(
                            fontSize: AppTheme.textSmall,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spaceXLarge),

                // ── Bouton valider ────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLarge),
                  child: AppButton(
                    text: 'Valider et continuer',
                    icon: Icons.check,
                    loading: _loading,
                    onPressed: _photo == null ? null : _uploadPhoto,
                    customColor: AppColors.etudiant,
                  ),
                ),

                const SizedBox(height: AppTheme.spaceXLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}