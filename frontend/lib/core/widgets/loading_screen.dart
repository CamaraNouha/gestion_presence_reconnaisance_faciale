// ============================================================
// LOADING SCREEN — Écran de chargement
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class LoadingScreen extends StatelessWidget {
  final String? message;

  const LoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            if (message != null) ...[
              const SizedBox(height: AppTheme.spaceLarge),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: AppTheme.textMedium,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Loading inline (à mettre dans une page) ──────────────────
class LoadingInline extends StatelessWidget {
  const LoadingInline({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXLarge),
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 3,
        ),
      ),
    );
  }
}