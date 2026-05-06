// ============================================================
// ATTENDANCE TILE — Ligne de présence
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AttendanceTile extends StatelessWidget {
  final String nom;
  final String prenom;
  final String? statut; // 'present', 'absent', null (en attente)
  final DateTime? pointedAt;
  final VoidCallback? onMarkPresent;
  final VoidCallback? onMarkAbsent;
  final bool showActions;

  const AttendanceTile({
    super.key,
    required this.nom,
    required this.prenom,
    this.statut,
    this.pointedAt,
    this.onMarkPresent,
    this.onMarkAbsent,
    this.showActions = false,
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
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColorLight,
                  borderRadius: BorderRadius.circular(22),
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

              // Nom + heure
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
                    if (pointedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pointé à ${_formatTime(pointedAt!)}',
                        style: const TextStyle(
                          fontSize: AppTheme.textXSmall,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Badge statut
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _statusColorLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_statusIcon, size: 12, color: _statusColor),
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

          // Actions (prof seulement)
          if (showActions) ...[
            const SizedBox(height: AppTheme.spaceMedium),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: statut == 'present' ? null : onMarkPresent,
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: const Text('Présent'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: statut == 'absent' ? null : onMarkAbsent,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Absent'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}