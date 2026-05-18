// ============================================================
// DASHBOARD PROFESSEUR — Page d'accueil
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/stat_box.dart';
import '../../core/widgets/loading_screen.dart';

import '../auth/login_screen.dart';
import 'sessions/open_session_screen.dart';
import 'sessions/active_session_screen.dart';
import 'sessions/sessions_history_screen.dart';
import 'modules/my_modules_screen.dart';
import 'profile/professeur_profile_screen.dart';

class ProfesseurDashboard extends StatefulWidget {
  const ProfesseurDashboard({super.key});

  @override
  State<ProfesseurDashboard> createState() => _ProfesseurDashboardState();
}

class _ProfesseurDashboardState extends State<ProfesseurDashboard> {
  bool _loading = true;
  String _name = '';
  List<dynamic> _modules = [];
  List<dynamic> _activeSessions = [];
  int _totalSessions = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      _name = await StorageService.getFullName();

      // Modules du prof
      _modules = await ApiService.getProfModules();

      // Sessions actives du prof
      final allActive = await ApiService.getActiveSessions();
      final myModuleIds = _modules.map((m) => m['id']).toList();
      _activeSessions = allActive
          .where((s) => myModuleIds.contains(s['module_id']))
          .toList();

      // Total sessions (historique)
      final mySessions = await ApiService.getMySessions();
      _totalSessions = mySessions.length;
    } catch (e) {
      print('Erreur dashboard prof: $e');
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

  // ── Trouve le nom d'un module ─────────────────────────────
  String _getModuleName(String moduleId) {
    final m = _modules.firstWhere(
      (m) => m['id'] == moduleId,
      orElse: () => null,
    );
    return m?['nom'] ?? 'Module';
  }

  // ── Aller à une session active ────────────────────────────
  Future<void> _goToActiveSession(Map<String, dynamic> session) async {
    final moduleName = _getModuleName(session['module_id']);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          sessionId: session['id'],
          moduleName: moduleName,
        ),
      ),
    );
    _loadData();
  }

  // ── Ouvrir une nouvelle session ───────────────────────────
  Future<void> _goToOpenSession() async {
    if (_modules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun module assigné'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpenSessionScreen(modules: _modules),
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
        color: AppColors.professeur,
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header bleu ─────────────────────────────────
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
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_activeSessions.length} session(s) en cours',
                            style: const TextStyle(
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
                        label: 'Mes modules',
                        value: '${_modules.length}',
                        color: AppColors.primary,
                        onTap: _goToMyModules,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMedium),
                    Expanded(
                      child: StatBox(
                        icon: Icons.history,
                        label: 'Sessions',
                        value: '$_totalSessions',
                        color: AppColors.info,
                        onTap: _goToHistory,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceXLarge),

              // ── Action principale : Ouvrir session ─────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceLarge),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _goToOpenSession,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLarge),
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spaceLarge),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.success,
                            Color(0xFF2BB585),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLarge),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spaceMedium),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ouvrir une session',
                                  style: TextStyle(
                                    fontSize: AppTheme.textLarge,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Lancer le pointage pour un cours',
                                  style: TextStyle(
                                    fontSize: AppTheme.textSmall,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      subtitle: 'Modules assignés',
                      color: AppColors.primary,
                      onTap: _goToMyModules,
                    ),

                    const SizedBox(height: AppTheme.spaceSmall),

                    _buildMenuItem(
                      icon: Icons.history,
                      title: 'Historique',
                      subtitle: 'Sessions passées',
                      color: AppColors.info,
                      onTap: _goToHistory,
                    ),

                    const SizedBox(height: AppTheme.spaceSmall),

                    _buildMenuItem(
                      icon: Icons.person_outline,
                      title: 'Mon Profil',
                      subtitle: 'Mes informations',
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
          colors: [AppColors.professeur, Color(0xFF3079C0)],
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
                  Icons.school,
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
                      'Pr. $_name',
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
                Icon(Icons.school_outlined,
                    color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'Espace Professeur',
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
    final moduleName = _getModuleName(session['module_id']);
    final delai = session['delai_minutes'] ?? 15;

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
          onTap: () => _goToActiveSession(session),
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
                    Icons.fiber_manual_record,
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
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Délai : $delai min',
                            style: const TextStyle(
                              fontSize: AppTheme.textSmall,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  void _goToMyModules() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfMyModulesScreen()),
    );
  }

  void _goToHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SessionsHistoryScreen()),
    );
    _loadData();
  }

  void _goToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfesseurProfileScreen()),
    );
    _loadData();
  }
}