// ============================================================
// DASHBOARD ÉTUDIANT — Page d'accueil
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/stat_box.dart';
import '../../core/widgets/loading_screen.dart';
import '../auth/login_screen.dart';
import 'modules/my_modules_screen.dart';
import 'history/history_screen.dart';
import 'profile/etudiant_profile_screen.dart';
import 'checkin/checkin_screen.dart';

class EtudiantDashboard extends StatefulWidget {
  const EtudiantDashboard({super.key});

  @override
  State<EtudiantDashboard> createState() => _EtudiantDashboardState();
}

class _EtudiantDashboardState extends State<EtudiantDashboard> {
  bool _loading = true;
  String _name = '';
  int _totalModules = 0;
  int _totalPresent = 0;
  int _totalAbsent = 0;
  List<dynamic> _activeSessions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      _name = await StorageService.getFullName();

      // Modules
      final modules = await ApiService.getMyModules();
      _totalModules = modules.length;

      // Présences
      final attendances = await ApiService.getMyAttendances();
      _totalPresent =
          attendances.where((a) => a['statut'] == 'present').length;
      _totalAbsent =
          attendances.where((a) => a['statut'] == 'absent').length;

      // Sessions actives (pour pointer)
      final allActive = await ApiService.getActiveSessions();
      // Filtrer les sessions qui correspondent aux modules de l'étudiant
      final myModuleIds = modules.map((m) => m['id']).toList();
      _activeSessions = allActive
          .where((s) => myModuleIds.contains(s['module_id']))
          .toList();
    } catch (e) {
      print('Erreur dashboard étudiant: $e');
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

  // ── Trouve le nom du module pour une session ──────────────
  Future<String> _getModuleName(String moduleId) async {
    try {
      final modules = await ApiService.getMyModules();
      final module = modules.firstWhere(
        (m) => m['id'] == moduleId,
        orElse: () => null,
      );
      return module?['nom'] ?? 'Module';
    } catch (e) {
      return 'Module';
    }
  }

  // ── Aller au pointage ─────────────────────────────────────
  Future<void> _goToCheckin(Map<String, dynamic> session) async {
    final moduleName = await _getModuleName(session['module_id']);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckinScreen(
          sessionId: session['id'],
          moduleName: moduleName,
        ),
      ),
    );
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingScreen(message: 'Chargement...');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.etudiant,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header vert ─────────────────────────────────
              _buildHeader(),

              // ── Sessions actives ────────────────────────────
              if (_activeSessions.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceLarge),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLarge),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Session active',
                            style: TextStyle(
                              fontSize: AppTheme.textLarge,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceMedium),
                      ..._activeSessions.map(_buildActiveSessionCard),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spaceLarge),

              // ── Stats ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLarge),
                child: Row(
                  children: [
                    Expanded(
                      child: StatBox(
                        icon: Icons.book_outlined,
                        label: 'Modules',
                        value: '$_totalModules',
                        color: AppColors.primary,
                        onTap: _goToModules,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      child: StatBox(
                        icon: Icons.check_circle_outline,
                        label: 'Présences',
                        value: '$_totalPresent',
                        color: AppColors.success,
                        onTap: _goToHistory,
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
                  icon: Icons.cancel_outlined,
                  label: 'Absences',
                  value: '$_totalAbsent',
                  color: AppColors.error,
                  onTap: _goToHistory,
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
                      'Menu',
                      style: TextStyle(
                        fontSize: AppTheme.textLarge,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMedium),

                    _buildMenuItem(
                      icon: Icons.book,
                      title: 'Mes Modules',
                      subtitle: 'Voir mes inscriptions',
                      color: AppColors.primary,
                      onTap: _goToModules,
                    ),

                    const SizedBox(height: AppTheme.spaceSmall),

                    _buildMenuItem(
                      icon: Icons.history,
                      title: 'Historique',
                      subtitle: 'Mes présences passées',
                      color: AppColors.info,
                      onTap: _goToHistory,
                    ),

                    const SizedBox(height: AppTheme.spaceSmall),

                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Mon Profil',
                      subtitle: 'Modifier mes informations',
                      color: AppColors.warning,
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person,
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
                      _name,
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
                Icon(Icons.school, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'Espace Étudiant',
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

  // ── Card de session active ────────────────────────────────
  Widget _buildActiveSessionCard(dynamic session) {
    return FutureBuilder<String>(
      future: _getModuleName(session['module_id']),
      builder: (context, snapshot) {
        final moduleName = snapshot.data ?? 'Chargement...';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.success.withOpacity(0.1),
                AppColors.success.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppColors.success, width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _goToCheckin(session),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceLarge),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            moduleName,
                            style: const TextStyle(
                              fontSize: AppTheme.textMedium,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tape pour pointer',
                            style: TextStyle(
                              fontSize: AppTheme.textSmall,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
  void _goToModules() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyModulesScreen()),
    );
    _loadData();
  }

  void _goToHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  void _goToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EtudiantProfileScreen()),
    );
    _loadData();
  }
}