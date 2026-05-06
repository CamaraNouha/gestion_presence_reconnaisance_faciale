// ============================================================
// CRÉER UN UTILISATEUR — Vue Admin
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/message_box.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _apogeeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _role = 'etudiant';
  File? _photo;
  bool _loading = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    _apogeeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
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
            ListTile(
              leading: const Icon(
                Icons.camera_alt,
                color: AppColors.admin,
              ),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.admin,
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  // ── Création ──────────────────────────────────────────────
  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'etudiant' && _photo == null) {
      MessageBox.show(
        context,
        message: 'La photo est obligatoire pour un étudiant',
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiService.createUser(
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        apogee: _apogeeCtrl.text.trim(),
        role: _role,
        motDePasse: _passwordCtrl.text,
        photoPath: _photo?.path,
      );

      if (!mounted) return;

      MessageBox.show(
        context,
        message: 'Utilisateur créé avec succès',
        type: MessageType.success,
      );

      Navigator.pop(context, true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        title: const Text('Nouvel utilisateur'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sélection rôle
              const Text(
                'Type de compte',
                style: TextStyle(
                  fontSize: AppTheme.textSmall,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSmall),
              Row(
                children: [
                  Expanded(
                    child: _buildRoleCard(
                      label: 'Étudiant',
                      icon: Icons.person_outline,
                      value: 'etudiant',
                      color: AppColors.etudiant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRoleCard(
                      label: 'Professeur',
                      icon: Icons.school_outlined,
                      value: 'professeur',
                      color: AppColors.professeur,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRoleCard(
                      label: 'Admin',
                      icon: Icons.admin_panel_settings_outlined,
                      value: 'admin',
                      color: AppColors.admin,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spaceXLarge),

              // Photo (uniquement étudiant)
              if (_role == 'etudiant') ...[
                const Text(
                  'Photo (obligatoire)',
                  style: TextStyle(
                    fontSize: AppTheme.textSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSmall),
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: _photo != null
                            ? Colors.transparent
                            : AppColors.adminLight,
                        borderRadius: BorderRadius.circular(70),
                        border: Border.all(
                          color: AppColors.admin,
                          width: 2,
                        ),
                      ),
                      child: _photo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(70),
                              child: Image.file(
                                _photo!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 40,
                                  color: AppColors.admin,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Ajouter\nune photo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: AppTheme.textSmall,
                                    color: AppColors.admin,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                if (_photo != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Changer la photo'),
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.spaceLarge),
              ],

              // Champs
              AppTextField(
                controller: _prenomCtrl,
                label: 'Prénom',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Prénom requis'
                    : null,
              ),
              const SizedBox(height: AppTheme.spaceMedium),

              AppTextField(
                controller: _nomCtrl,
                label: 'Nom',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nom requis'
                    : null,
              ),
              const SizedBox(height: AppTheme.spaceMedium),

              AppTextField(
                controller: _emailCtrl,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email requis';
                  }
                  if (!v.contains('@')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spaceMedium),

              AppTextField(
                controller: _apogeeCtrl,
                label: 'Numéro Apogée',
                hint: 'Identifiant unique',
                icon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Apogée requis'
                    : null,
              ),
              const SizedBox(height: AppTheme.spaceMedium),

              AppTextField(
                controller: _passwordCtrl,
                label: 'Mot de passe',
                hint: 'Au moins 4 caractères',
                icon: Icons.lock_outline,
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Mot de passe requis';
                  }
                  if (v.length < 4) {
                    return 'Au moins 4 caractères';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppTheme.spaceXLarge),

              AppButton(
                text: 'Créer l\'utilisateur',
                icon: Icons.check,
                loading: _loading,
                onPressed: _create,
                customColor: AppColors.admin,
              ),

              const SizedBox(height: AppTheme.spaceXLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String label,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.textXSmall,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}