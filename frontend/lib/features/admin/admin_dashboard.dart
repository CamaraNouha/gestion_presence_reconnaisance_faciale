// ============================================================
// DASHBOARD ADMIN — Page d'accueil de l'administrateur
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/stat_box.dart';
import '../../core/widgets/loading_screen.dart';
import '../auth/login_screen.dart';
import 'users/users_list_screen.dart';
import 'modules/modules_list_screen.dart';
import 'profile/admin_profile_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  String _adminName = '';
  int _totalStudents = 0;
  int _totalProfs = 0;
  int _totalModules = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      // Récupère le nom admin
      _adminName = await StorageService.getFullName();

      // Récupère les utilisateurs
      final users = await ApiService.getAllUsers();
      _totalStudents = users.where((u) => u['role'] == 'etudiant').length;
      _totalProfs = users.where((u) => u['role'] == 'professeur').length;

      // Récupère les modules
      final modules = await ApiService.getAllModules();
      _totalModules = modules.length;
    } catch (e) {
      print('Erreur chargement dashboard: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    if (_loading) {
      return const LoadingScreen(message: 'Chargement...');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.admin,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header avec dégradé violet ──────────────────
              _buildHeader(),

              const SizedBox(height: AppTheme.spaceLarge),

              // ── Stats ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLarge),
                child: Row(
                  children: [
                    Expanded(
                      child: StatBox(
                        icon: Icons.people_outline,
                        label: 'Étudiants',
                        value: '$_totalStudents',
                        color: AppColors.etudiant,
                        onTap: () => _goToUsersList('etudiant'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      child: StatBox(
                        icon: Icons.school_outlined,
                        label: 'Professeurs',
                        value: '$_totalProfs',
                        color: AppColors.professeur,
                        onTap: () => _goToUsersList('professeur'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceMedium),

              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLarge),
                child: StatBox(
                  icon: Icons.book_outlined,
                  label: 'Modules',
                  value: '$_totalModules',
                  color: AppColors.primary,
                  onTap: _goToModules,
                ),
              ),

              const SizedBox(height: AppTheme.spaceXLarge),

              // ── Menu ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gestion',
                      style: TextStyle(
                        fontSize: AppTheme.textLarge,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMedium),

                    _buildMenuItem(
                      icon: Icons.people,
                      title: 'Utilisateurs',
                      subtitle: 'Étudiants, professeurs, admins',
                      color: AppColors.admin,
                      onTap: () => _goToUsersList(null),
                    ),

                    const SizedBox(height: AppTheme.spaceSmall),

                    _buildMenuItem(
                      icon: Icons.book,
                      title: 'Modules',
                      subtitle: 'Créer et gérer les modules',
                      color: AppColors.primary,
                      onTap: _goToModules,
                    ),

                    const SizedBox(height: AppTheme.spaceSmall),

                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Mon Profil',
                      subtitle: 'Modifier mes informations',
                      color: AppColors.info,
                      onTap: _goToProfile,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceXLarge),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.admin, Color(0xFF6362D9)],
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour,',
                      style: TextStyle(
                        fontSize: AppTheme.textSmall,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    Text(
                      _adminName,
                      style: const TextStyle(
                        fontSize: AppTheme.textLarge,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: _logout,
                tooltip: 'Déconnexion',
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLarge),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined,
                    color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'Espace Administrateur',
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
    );
  }

  // ── Menu Item ─────────────────────────────────────────────
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: AppTheme.textMedium,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: AppTheme.textSmall,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
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

  // ── Navigation ────────────────────────────────────────────
  void _goToUsersList(String? filter) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UsersListScreen(initialFilter: filter),
      ),
    );
    _loadData();
  }

  void _goToModules() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ModulesListScreen()),
    );
    _loadData();
  }

  void _goToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
    );
  }
}