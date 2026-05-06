// ============================================================
// APP HEADER — En-tête avec couleur de rôle
// ============================================================

import 'package:flutter/material.dart';
//import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color color;
  final IconData icon;
  final List<Widget>? actions;

  const AppHeader({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppTheme.textXLarge,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: AppTheme.textSmall,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}