// ============================================================
// SESSION ACTIVE — Vue Professeur (temps réel)
// ============================================================
// Auto-refresh toutes les 5 secondes
// Modifier le statut des étudiants
// Exporter / Fermer la session
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';
import '../../../core/widgets/student_attendance_card.dart';

class ActiveSessionScreen extends StatefulWidget {
  final String sessionId;
  final String moduleName;

  const ActiveSessionScreen({
    super.key,
    required this.sessionId,
    required this.moduleName,
  });

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  bool _loading = true;
  bool _sessionClosed = false;
  List<dynamic> _attendances = [];
  Timer? _refreshTimer;
  String _filter = 'all'; // 'all', 'present', 'absent', 'pending'

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ── Auto-refresh toutes les 5 secondes ────────────────────
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!_sessionClosed && mounted) {
          _loadData(silent: true);
        }
      },
    );
  }

  // ── Charge les données ────────────────────────────────────
  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    try {
      // Récupère les présences avec infos étudiants
      _attendances = await ApiService.getSessionAttendances(
        widget.sessionId,
      );

      // Trie par ID étudiant pour avoir un ordre stable
      _attendances.sort((a, b) {
        final idA = a['etudiant_id']?.toString() ?? '';
        final idB = b['etudiant_id']?.toString() ?? '';
        return idA.compareTo(idB);
      });

      // Récupère le statut réel de la session
      final sessionInfo = await ApiService.getSessionInfo(widget.sessionId);
      if (sessionInfo != null) {
        final statut = sessionInfo['statut'];
        if (statut == 'fermee') {
          _sessionClosed = true;
          // Arrête l'auto-refresh si la session est fermée
          _refreshTimer?.cancel();
        } else {
          _sessionClosed = false;
        }
      }
    } catch (e) {
      if (!silent && mounted) {
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

  // ── Modifier le statut d'un étudiant ──────────────────────
  Future<void> _updateStatus(
    String studentId,
    String newStatut,
  ) async {
    // Met en pause l'auto-refresh pendant la modification
    _refreshTimer?.cancel();

    try {
      await ApiService.updateAttendanceStatus(
        sessionId: widget.sessionId,
        studentId: studentId,
        statut: newStatut,
      );

      if (!mounted) return;

      MessageBox.show(
        context,
        message: newStatut == 'present'
            ? 'Étudiant marqué présent'
            : 'Étudiant marqué absent',
        type: MessageType.success,
      );

      // Recharge les données
      await _loadData(silent: true);
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    } finally {
      // Réactive l'auto-refresh si la session est toujours active
      if (!_sessionClosed && mounted) {
        _startAutoRefresh();
      }
    }
  }

  // ── Fermer la session ─────────────────────────────────────
  Future<void> _closeSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fermer la session'),
        content: const Text(
          'Voulez-vous vraiment fermer cette session ?\n\nLes étudiants non pointés seront marqués absents automatiquement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.closeSession(widget.sessionId);

      if (!mounted) return;

      _refreshTimer?.cancel();
      setState(() => _sessionClosed = true);

      MessageBox.show(
        context,
        message: 'Session fermée',
        type: MessageType.success,
      );

      // Recharge les données pour avoir les statuts finaux
      _loadData();
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    }
  }

  // ── Export ────────────────────────────────────────────────
  Future<void> _showExportSheet() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                'Exporter les présences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.table_chart,
                color: AppColors.success,
                size: 32,
              ),
              title: const Text('Excel (.xlsx)'),
              subtitle: const Text('Format complet avec mise en forme'),
              onTap: () {
                Navigator.pop(ctx);
                _doExport('excel');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.description,
                color: AppColors.info,
                size: 32,
              ),
              title: const Text('CSV (.csv)'),
              subtitle: const Text('Format simple'),
              onTap: () {
                Navigator.pop(ctx);
                _doExport('csv');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _doExport(String format) async {
    try {
      MessageBox.show(
        context,
        message: 'Téléchargement en cours...',
        type: MessageType.info,
      );

      await ApiService.downloadExport(
        sessionId: widget.sessionId,
        format: format,
      );

      if (!mounted) return;

      MessageBox.show(
        context,
        message: 'Export téléchargé',
        type: MessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    }
  }

  // ── Stats ─────────────────────────────────────────────────
  int get _totalPresent =>
      _attendances.where((a) => a['statut'] == 'present').length;

  int get _totalAbsent =>
      _attendances.where((a) => a['statut'] == 'absent').length;

  int get _totalPending =>
      _attendances.where((a) => a['statut'] == null).length;

  int get _totalStudents => _attendances.length;

  // ── Liste filtrée ─────────────────────────────────────────
  List<dynamic> get _filteredAttendances {
    if (_filter == 'all') return _attendances;
    if (_filter == 'pending') {
      return _attendances.where((a) => a['statut'] == null).toList();
    }
    return _attendances.where((a) => a['statut'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.professeur,
          title: const Text('Session'),
        ),
        body: const LoadingInline(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header avec stats ────────────────────────────
          _buildHeader(),

          // ── Filtres ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip(
                    'Tous',
                    'all',
                    _totalStudents,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Présents',
                    'present',
                    _totalPresent,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Absents',
                    'absent',
                    _totalAbsent,
                    color: AppColors.error,
                  ),
                  if (!_sessionClosed) ...[
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'En attente',
                      'pending',
                      _totalPending,
                      color: AppColors.warning,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Liste ───────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.professeur,
              onRefresh: () => _loadData(),
              child: _filteredAttendances.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.people_outline,
                          title: 'Aucun étudiant',
                          message:
                              'Aucun étudiant ne correspond au filtre',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 100),
                      itemCount: _filteredAttendances.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final att = _filteredAttendances[i];
                        final student = att['etudiant'] as Map<String, dynamic>?;
                        final etudiantId = att['etudiant_id']?.toString() ?? '';

                        if (student == null) {
                          return const SizedBox.shrink();
                        }

                        DateTime? pointedAt;
                        if (att['pointed_at'] != null) {
                          try {
                            pointedAt = DateTime.parse(att['pointed_at']).toLocal();
                          } catch (e) {}
                        }

                        return KeyedSubtree(
                          key: ValueKey('attendance_$etudiantId'),
                          child: StudentAttendanceCard(
                            nom: student['nom'] ?? '',
                            prenom: student['prenom'] ?? '',
                            apogee: student['apogee'],
                            statut: att['statut'],
                            pointedAt: pointedAt,
                            sessionActive: true,
                            onMarkPresent: () => _updateStatus(etudiantId, 'present'),
                            onMarkAbsent: () => _updateStatus(etudiantId, 'absent'),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),

      // ── Bouton flottant ──────────────────────────────────
      floatingActionButton: _buildFAB(),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _sessionClosed
              ? [AppColors.textGrey, AppColors.textGrey]
              : [AppColors.professeur, const Color(0xFF3079C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // App bar custom
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!_sessionClosed) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'EN DIRECT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Text(
                              'TERMINÉE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            widget.moduleName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_sessionClosed || _attendances.isNotEmpty)
                IconButton(
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: Colors.white,
                  ),
                  onPressed: _showExportSheet,
                  tooltip: 'Exporter',
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  icon: Icons.check_circle,
                  label: 'Présents',
                  value: '$_totalPresent',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  icon: Icons.cancel,
                  label: 'Absents',
                  value: '$_totalAbsent',
                  color: AppColors.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatBox(
                  icon: Icons.access_time,
                  label: _sessionClosed ? 'Total' : 'Attente',
                  value:
                      '${_sessionClosed ? _totalStudents : _totalPending}',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stat box dans header ──────────────────────────────────
  Widget _buildStatBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
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
              fontSize: 11,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chip ───────────────────────────────────────────
  Widget _buildFilterChip(
    String label,
    String value,
    int count, {
    Color? color,
  }) {
    final selected = _filter == value;
    final chipColor = color ?? AppColors.professeur;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? chipColor : chipColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTheme.textSmall,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : chipColor,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.3)
                      : chipColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB Fermer la session ─────────────────────────────────
  Widget? _buildFAB() {
    if (_sessionClosed) return null;

    return FloatingActionButton.extended(
      onPressed: _closeSession,
      backgroundColor: AppColors.error,
      icon: const Icon(Icons.stop_circle, color: Colors.white),
      label: const Text(
        'Fermer la session',
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}