// ============================================================
// APP CARD — Carte stylisée
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? background;
  final VoidCallback? onTap;
  final Border? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.background,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding ?? const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: background ?? Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: border,
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset:  Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: content,
        ),
      );
    }

    return content;
  }
}