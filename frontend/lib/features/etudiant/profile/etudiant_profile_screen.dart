// ============================================================
// PROFIL ÉTUDIANT — Placeholder
// Le vrai écran sera identique à AdminProfile mais en vert
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../auth/login_screen.dart';

class EtudiantProfileScreen extends StatefulWidget {
  const EtudiantProfileScreen({super.key});

  @override
  State<EtudiantProfileScreen> createState() =>
      _EtudiantProfileScreenState();
}

class _EtudiantProfileScreenState extends State<EtudiantProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      _user = await ApiService.getMyProfile();
    } catch (e) {
      if (mounted) {
        MessageBox.show(
          context,
          message: 'Erreur de chargement',
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditProfileSheet(user: _user!),
    );
    if (result == true) _loadProfile();
  }

  Future<void> _changePassword() async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _ChangePasswordSheet(),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
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
    if (_loading || _user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.etudiant,
          title: const Text('Mon Profil'),
        ),
        body: const LoadingInline(),
      );
    }

    final initials =
        '${(_user!['prenom'] ?? '').isNotEmpty ? _user!['prenom'][0] : ''}${(_user!['nom'] ?? '').isNotEmpty ? _user!['nom'][0] : ''}'
            .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
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
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Mon Profil',
                        style: TextStyle(
                          fontSize: AppTheme.textLarge,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceLarge),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.etudiant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMedium),
                  Text(
                    '${_user!['prenom']} ${_user!['nom']}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Étudiant',
                          style: TextStyle(
                            fontSize: AppTheme.textXSmall,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceLarge),

            // Infos
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLarge),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.person_outline,
                      label: 'Prénom',
                      value: _user!['prenom'] ?? '',
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _buildInfoTile(
                      icon: Icons.person_outline,
                      label: 'Nom',
                      value: _user!['nom'] ?? '',
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: _user!['email'] ?? '',
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    _buildInfoTile(
                      icon: Icons.badge_outlined,
                      label: 'Apogée',
                      value: _user!['apogee'] ?? '',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spaceLarge),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLarge),
              child: Column(
                children: [
                  _buildActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Modifier mes informations',
                    color: AppColors.etudiant,
                    onTap: _editProfile,
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  _buildActionTile(
                    icon: Icons.lock_outline,
                    title: 'Changer le mot de passe',
                    color: AppColors.warning,
                    onTap: _changePassword,
                  ),
                  const SizedBox(height: AppTheme.spaceSmall),
                  _buildActionTile(
                    icon: Icons.logout,
                    title: 'Se déconnecter',
                    color: AppColors.error,
                    onTap: _logout,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceXLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textGrey),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppTheme.textXSmall,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: AppTheme.textMedium,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.textMedium,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOTTOM SHEETS
// ============================================================

class _EditProfileSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  const _EditProfileSheet({required this.user});

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _emailCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.user['nom'] ?? '');
    _prenomCtrl = TextEditingController(text: widget.user['prenom'] ?? '');
    _emailCtrl = TextEditingController(text: widget.user['email'] ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await ApiService.updateMyProfile(
        nom: _nomCtrl.text.trim(),
        prenom: _prenomCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      MessageBox.show(
        context,
        message: 'Profil mis à jour',
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  'Modifier mes informations',
                  style: TextStyle(
                    fontSize: AppTheme.textLarge,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLarge),
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
                    if (v == null || v.trim().isEmpty) return 'Email requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                AppButton(
                  text: 'Enregistrer',
                  icon: Icons.check,
                  loading: _loading,
                  onPressed: _save,
                  customColor: AppColors.etudiant,
                ),
                const SizedBox(height: AppTheme.spaceMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ancienCtrl = TextEditingController();
  final _nouveauCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ancienCtrl.dispose();
    _nouveauCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_nouveauCtrl.text != _confirmCtrl.text) {
      MessageBox.show(
        context,
        message: 'Les mots de passe ne correspondent pas',
        type: MessageType.error,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiService.changePassword(
        ancien: _ancienCtrl.text,
        nouveau: _nouveauCtrl.text,
      );
      if (!mounted) return;
      MessageBox.show(
        context,
        message: 'Mot de passe modifié',
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const Text(
                  'Changer le mot de passe',
                  style: TextStyle(
                    fontSize: AppTheme.textLarge,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLarge),
                AppTextField(
                  controller: _ancienCtrl,
                  label: 'Ancien mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: AppTheme.spaceMedium),
                AppTextField(
                  controller: _nouveauCtrl,
                  label: 'Nouveau mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (v.length < 4) return 'Au moins 4 caractères';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.spaceMedium),
                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Confirmer le mot de passe',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: AppTheme.spaceXLarge),
                AppButton(
                  text: 'Modifier',
                  icon: Icons.check,
                  loading: _loading,
                  onPressed: _save,
                  customColor: AppColors.warning,
                ),
                const SizedBox(height: AppTheme.spaceMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}