// ============================================================
// EMPTY STATE — Affichage d'une liste vide
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: AppTheme.spaceLarge),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.textLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSmall),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppTheme.textMedium,
                color: AppColors.textGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}