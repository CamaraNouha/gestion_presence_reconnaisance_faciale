// ============================================================
// HISTORIQUE DES SESSIONS — Vue Professeur
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';
import 'active_session_screen.dart';

class SessionsHistoryScreen extends StatefulWidget {
  const SessionsHistoryScreen({super.key});

  @override
  State<SessionsHistoryScreen> createState() =>
      _SessionsHistoryScreenState();
}

class _SessionsHistoryScreenState extends State<SessionsHistoryScreen> {
  bool _loading = true;
  List<dynamic> _sessions = [];
  List<dynamic> _modules = [];
  String _filter = 'all'; // 'all', 'ouverte', 'fermee'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _sessions = await ApiService.getMySessions();
      _modules = await ApiService.getProfModules();
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

  // ── Récupère le nom du module ─────────────────────────────
  String _getModuleName(String moduleId) {
    final m = _modules.firstWhere(
      (m) => m['id'] == moduleId,
      orElse: () => null,
    );
    return m?['nom'] ?? 'Module';
  }

  // ── Liste filtrée ─────────────────────────────────────────
  List<dynamic> get _filteredSessions {
    if (_filter == 'all') return _sessions;
    return _sessions.where((s) => s['statut'] == _filter).toList();
  }

  // ── Stats ─────────────────────────────────────────────────
  int get _totalSessions => _sessions.length;
  int get _openSessions =>
      _sessions.where((s) => s['statut'] == 'ouverte').length;
  int get _closedSessions =>
      _sessions.where((s) => s['statut'] == 'fermee').length;

  // ── Format date ───────────────────────────────────────────
  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      return '$day/$month/$year';
    } catch (e) {
      return '';
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (e) {
      return '';
    }
  }

  // ── Aller à la session ────────────────────────────────────
  Future<void> _goToSession(Map<String, dynamic> session) async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.professeur,
        title: const Text('Historique'),
        elevation: 0,
      ),
      body: _loading
          ? const LoadingInline()
          : Column(
              children: [
                // ── Stats header ─────────────────────────────
                Container(
                  color: AppColors.professeur,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.calculate_outlined,
                          label: 'Total',
                          value: '$_totalSessions',
                          color: AppColors.info,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.fiber_manual_record,
                          label: 'En cours',
                          value: '$_openSessions',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.history,
                          label: 'Terminées',
                          value: '$_closedSessions',
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Filtres ──────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('Toutes', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('En cours', 'ouverte'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Terminées', 'fermee'),
                      ],
                    ),
                  ),
                ),

                // ── Liste ────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.professeur,
                    onRefresh: _loadData,
                    child: _filteredSessions.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.history,
                                title: 'Aucune session',
                                message:
                                    'Aucune session ne correspond aux critères',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredSessions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final s = _filteredSessions[i];
                              return _buildSessionCard(s);
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Stat tile ─────────────────────────────────────────────
  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: AppTheme.textXSmall,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chip ───────────────────────────────────────────
  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.professeur
                : AppColors.professeurLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.textSmall,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.professeur,
            ),
          ),
        ),
      ),
    );
  }

  // ── Card de session ───────────────────────────────────────
  Widget _buildSessionCard(Map<String, dynamic> session) {
    final isOpen = session['statut'] == 'ouverte';
    final color = isOpen ? AppColors.success : AppColors.textGrey;
    final colorLight =
        isOpen ? AppColors.successLight : AppColors.background;

    final moduleName = _getModuleName(session['module_id']);
    final delai = session['delai_minutes'] ?? 15;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _goToSession(session),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: isOpen ? AppColors.success : AppColors.border,
              width: isOpen ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isOpen
                          ? Icons.fiber_manual_record
                          : Icons.history,
                      color: color,
                      size: 22,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isOpen ? 'EN COURS' : 'Terminée',
                            style: TextStyle(
                              fontSize: AppTheme.textXSmall,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
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

              const Divider(height: 24, color: AppColors.divider),

              // Infos
              Row(
                children: [
                  // Date
                  Expanded(
                    child: _buildInfoBlock(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: _formatDate(session['debut_at']),
                    ),
                  ),
                  // Heure
                  Expanded(
                    child: _buildInfoBlock(
                      icon: Icons.access_time,
                      label: 'Heure',
                      value: _formatTime(session['debut_at']),
                    ),
                  ),
                  // Délai
                  Expanded(
                    child: _buildInfoBlock(
                      icon: Icons.timer_outlined,
                      label: 'Délai',
                      value: '$delai min',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bloc d'info ───────────────────────────────────────────
  Widget _buildInfoBlock({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 14, color: AppColors.textGrey),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppTheme.textSmall,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.textXSmall,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}