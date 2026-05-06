// ============================================================
// HISTORIQUE DES PRÉSENCES — Vue Étudiant
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loading = true;
  List<dynamic> _attendances = [];
  String _filter = 'all'; // 'all', 'present', 'absent'

  @override
  void initState() {
    super.initState();
    _loadAttendances();
  }

  Future<void> _loadAttendances() async {
    setState(() => _loading = true);
    try {
      _attendances = await ApiService.getMyAttendances();
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

  // ── Liste filtrée ─────────────────────────────────────────
  List<dynamic> get _filtered {
    if (_filter == 'all') return _attendances;
    return _attendances.where((a) => a['statut'] == _filter).toList();
  }

  // ── Stats ─────────────────────────────────────────────────
  int get _present =>
      _attendances.where((a) => a['statut'] == 'present').length;
  int get _absent =>
      _attendances.where((a) => a['statut'] == 'absent').length;

  // ── Format date ───────────────────────────────────────────
  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year à $hour:$minute';
    } catch (e) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.etudiant,
        title: const Text('Historique'),
        elevation: 0,
      ),
      body: _loading
          ? const LoadingInline()
          : Column(
              children: [
                // ── Stats header ─────────────────────────────
                Container(
                  color: AppColors.etudiant,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.check_circle,
                          label: 'Présent',
                          value: '$_present',
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.cancel,
                          label: 'Absent',
                          value: '$_absent',
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatTile(
                          icon: Icons.calculate_outlined,
                          label: 'Total',
                          value: '${_attendances.length}',
                          color: AppColors.info,
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
                        _buildFilterChip('Tous', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Présent', 'present'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Absent', 'absent'),
                      ],
                    ),
                  ),
                ),

                // ── Liste ────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.etudiant,
                    onRefresh: _loadAttendances,
                    child: _filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.history,
                                title: 'Aucune présence',
                                message:
                                    'Aucun historique disponible',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final a = _filtered[i];
                              return _buildAttendanceCard(a);
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
            color: selected ? AppColors.etudiant : AppColors.etudiantLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.textSmall,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.etudiant,
            ),
          ),
        ),
      ),
    );
  }

  // ── Card de présence ──────────────────────────────────────
  Widget _buildAttendanceCard(Map<String, dynamic> attendance) {
    final statut = attendance['statut'];
    final isPresent = statut == 'present';
    final isAbsent = statut == 'absent';

    Color color = AppColors.warning;
    Color colorLight = AppColors.warningLight;
    IconData icon = Icons.access_time;
    String label = 'En attente';

    if (isPresent) {
      color = AppColors.success;
      colorLight = AppColors.successLight;
      icon = Icons.check_circle;
      label = 'Présent';
    } else if (isAbsent) {
      color = AppColors.error;
      colorLight = AppColors.errorLight;
      icon = Icons.cancel;
      label = 'Absent';
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icône statut
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppTheme.spaceMedium),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                        label,
                        style: TextStyle(
                          fontSize: AppTheme.textXSmall,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: AppColors.textGrey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(
                          attendance['pointed_at'] ?? attendance['created_at']),
                      style: const TextStyle(
                        fontSize: AppTheme.textSmall,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}