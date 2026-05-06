// ============================================================
// INSCRIRE DES ÉTUDIANTS À UN MODULE
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';

class EnrollStudentsScreen extends StatefulWidget {
  final String moduleId;
  final String moduleName;

  const EnrollStudentsScreen({
    super.key,
    required this.moduleId,
    required this.moduleName,
  });

  @override
  State<EnrollStudentsScreen> createState() => _EnrollStudentsScreenState();
}

class _EnrollStudentsScreenState extends State<EnrollStudentsScreen> {
  bool _loading = true;
  List<dynamic> _allStudents = [];
  List<dynamic> _enrolledStudents = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _allStudents = await ApiService.getStudents();
      _enrolledStudents =
          await ApiService.getModuleStudents(widget.moduleId);
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

  // ── Vérifie si un étudiant est inscrit ────────────────────
  bool _isEnrolled(String studentId) {
    return _enrolledStudents.any((s) => s['id'] == studentId);
  }

  // ── Liste filtrée par recherche ───────────────────────────
  List<dynamic> get _filteredStudents {
    if (_search.isEmpty) return _allStudents;
    final q = _search.toLowerCase();
    return _allStudents.where((s) {
      final nom = (s['nom'] ?? '').toString().toLowerCase();
      final prenom = (s['prenom'] ?? '').toString().toLowerCase();
      final apogee = (s['apogee'] ?? '').toString().toLowerCase();
      return nom.contains(q) ||
          prenom.contains(q) ||
          apogee.contains(q);
    }).toList();
  }

  // ── Toggle inscription ────────────────────────────────────
  Future<void> _toggleEnrollment(Map<String, dynamic> student) async {
    final isEnrolled = _isEnrolled(student['id']);

    try {
      if (isEnrolled) {
        await ApiService.removeStudentFromModule(
          moduleId: widget.moduleId,
          studentId: student['id'],
        );
        if (!mounted) return;
        MessageBox.show(
          context,
          message: '${student['prenom']} retiré du module',
          type: MessageType.info,
        );
      } else {
        await ApiService.assignStudentToModule(
          moduleId: widget.moduleId,
          studentId: student['id'],
        );
        if (!mounted) return;
        MessageBox.show(
          context,
          message: '${student['prenom']} inscrit au module',
          type: MessageType.success,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inscriptions',
              style: TextStyle(fontSize: 16),
            ),
            Text(
              widget.moduleName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.admin),
            )
          : Column(
              children: [
                // ── Stats ────────────────────────────────────
                Container(
                  color: AppColors.admin,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_enrolledStudents.length} étudiant(s) inscrit(s) sur ${_allStudents.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Barre de recherche
                      TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un étudiant...',
                          hintStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Liste des étudiants ──────────────────────
                Expanded(
                  child: _allStudents.isEmpty
                      ? const EmptyState(
                          icon: Icons.school_outlined,
                          title: 'Aucun étudiant',
                          message:
                              'Créez d\'abord des comptes étudiants',
                        )
                      : RefreshIndicator(
                          color: AppColors.admin,
                          onRefresh: _loadData,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredStudents.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final s = _filteredStudents[i];
                              return _buildStudentTile(s);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  // ── Tile étudiant avec toggle ─────────────────────────────
  Widget _buildStudentTile(Map<String, dynamic> student) {
    final enrolled = _isEnrolled(student['id']);
    final initials =
        '${(student['prenom'] ?? '').isNotEmpty ? student['prenom'][0] : ''}${(student['nom'] ?? '').isNotEmpty ? student['nom'][0] : ''}'
            .toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleEnrollment(student),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLarge),
          decoration: BoxDecoration(
            color: enrolled ? AppColors.successLight : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(
              color: enrolled ? AppColors.success : AppColors.border,
              width: enrolled ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enrolled
                      ? AppColors.success
                      : AppColors.etudiantLight,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: enrolled
                          ? Colors.white
                          : AppColors.etudiant,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: AppTheme.spaceMedium),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student['prenom']} ${student['nom']}',
                      style: const TextStyle(
                        fontSize: AppTheme.textMedium,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 12,
                          color: AppColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          student['apogee'] ?? '',
                          style: const TextStyle(
                            fontSize: AppTheme.textXSmall,
                            color: AppColors.textGrey,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bouton toggle
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: enrolled
                      ? AppColors.success
                      : AppColors.adminLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  enrolled ? Icons.check : Icons.add,
                  color: enrolled ? Colors.white : AppColors.admin,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}