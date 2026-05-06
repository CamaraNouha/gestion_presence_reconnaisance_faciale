// ============================================================
// MODULE TILE — Affiche un module dans une liste
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ModuleTile extends StatelessWidget {
  final String nom;
  final String code;
  final String? semestre;
  final String? filiere;
  final String? profNom;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const ModuleTile({
    super.key,
    required this.nom,
    required this.code,
    this.semestre,
    this.filiere,
    this.profNom,
    this.icon = Icons.book_outlined,
    this.color = AppColors.primary,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
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
              // Icône
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceMedium),

              // Info module
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nom,
                      style: const TextStyle(
                        fontSize: AppTheme.textMedium,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            code,
                            style: const TextStyle(
                              fontSize: AppTheme.textXSmall,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        if (semestre != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            semestre!,
                            style: const TextStyle(
                              fontSize: AppTheme.textXSmall,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (profNom != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 12,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              profNom!,
                              style: const TextStyle(
                                fontSize: AppTheme.textXSmall,
                                color: AppColors.textGrey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing (bouton ou flèche)
              if (trailing != null)
                trailing!
              else if (onTap != null)
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
}