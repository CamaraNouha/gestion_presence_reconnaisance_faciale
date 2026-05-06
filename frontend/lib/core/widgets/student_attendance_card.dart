// ============================================================
// STUDENT ATTENDANCE CARD — Carte étudiant dans une session
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class StudentAttendanceCard extends StatelessWidget {
  final String nom;
  final String prenom;
  final String? apogee;
  final String? statut; // 'present', 'absent', null
  final DateTime? pointedAt;
  final VoidCallback? onMarkPresent;
  final VoidCallback? onMarkAbsent;
  final bool sessionActive;

  const StudentAttendanceCard({
    super.key,
    required this.nom,
    required this.prenom,
    this.apogee,
    this.statut,
    this.pointedAt,
    this.onMarkPresent,
    this.onMarkAbsent,
    this.sessionActive = true,
  });

  String get _initials {
    final i1 = prenom.isNotEmpty ? prenom[0] : '';
    final i2 = nom.isNotEmpty ? nom[0] : '';
    return '$i1$i2'.toUpperCase();
  }

  Color get _statusColor {
    switch (statut) {
      case 'present':
        return AppColors.success;
      case 'absent':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  Color get _statusColorLight {
    switch (statut) {
      case 'present':
        return AppColors.successLight;
      case 'absent':
        return AppColors.errorLight;
      default:
        return AppColors.warningLight;
    }
  }

  IconData get _statusIcon {
    switch (statut) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      default:
        return Icons.access_time;
    }
  }

  String get _statusLabel {
    switch (statut) {
      case 'present':
        return 'Présent';
      case 'absent':
        return 'Absent';
      default:
        return 'En attente';
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // ── Ligne principale ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLarge),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _statusColorLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      _initials,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: AppTheme.spaceMedium),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$prenom $nom',
                        style: const TextStyle(
                          fontSize: AppTheme.textMedium,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (apogee != null) ...[
                            const Icon(
                              Icons.badge_outlined,
                              size: 11,
                              color: AppColors.textGrey,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              apogee!,
                              style: const TextStyle(
                                fontSize: AppTheme.textXSmall,
                                color: AppColors.textGrey,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (pointedAt != null) ...[
                            const Icon(
                              Icons.access_time,
                              size: 11,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatTime(pointedAt!),
                              style: const TextStyle(
                                fontSize: AppTheme.textXSmall,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Badge statut
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColorLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcon,
                        size: 14,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          fontSize: AppTheme.textXSmall,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Boutons d'actions ─────────────────────────────
          if (sessionActive) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed:
                          statut == 'present' ? null : onMarkPresent,
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                      ),
                      label: const Text(
                        'Présent',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.success,
                        disabledForegroundColor:
                            AppColors.success.withOpacity(0.3),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 20,
                    color: AppColors.divider,
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed:
                          statut == 'absent' ? null : onMarkAbsent,
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        'Absent',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        disabledForegroundColor:
                            AppColors.error.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}