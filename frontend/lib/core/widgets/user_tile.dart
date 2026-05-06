// ============================================================
// USER TILE — Affiche un utilisateur dans une liste
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class UserTile extends StatelessWidget {
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final String? apogee;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const UserTile({
    super.key,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    this.apogee,
    this.onTap,
    this.onDelete,
  });

  String get _initials {
    final i1 = prenom.isNotEmpty ? prenom[0] : '';
    final i2 = nom.isNotEmpty ? nom[0] : '';
    return '$i1$i2'.toUpperCase();
  }

  String get _roleLabel {
    switch (role) {
      case 'admin':
        return 'Administrateur';
      case 'professeur':
        return 'Professeur';
      case 'etudiant':
        return 'Étudiant';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forRole(role);
    final colorLight = AppColors.forRoleLight(role);

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
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMedium),

              // Info user
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
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: AppTheme.textSmall,
                        color: AppColors.textGrey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                            _roleLabel,
                            style: TextStyle(
                              fontSize: AppTheme.textXSmall,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ),
                        if (apogee != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '#$apogee',
                            style: const TextStyle(
                              fontSize: AppTheme.textXSmall,
                              color: AppColors.textGrey,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Bouton supprimer
              if (onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}