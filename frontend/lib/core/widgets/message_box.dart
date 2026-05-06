// ============================================================
// MESSAGE BOX — Boîte de message (succès, erreur, info, warning)
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum MessageType { success, error, info, warning }

class MessageBox extends StatelessWidget {
  final String message;
  final MessageType type;
  final IconData? icon;

  const MessageBox({
    super.key,
    required this.message,
    this.type = MessageType.info,
    this.icon,
  });

  Color get _bgColor {
    switch (type) {
      case MessageType.success:
        return AppColors.successLight;
      case MessageType.error:
        return AppColors.errorLight;
      case MessageType.warning:
        return AppColors.warningLight;
      case MessageType.info:
        return AppColors.infoLight;
    }
  }

  Color get _color {
    switch (type) {
      case MessageType.success:
        return AppColors.success;
      case MessageType.error:
        return AppColors.error;
      case MessageType.warning:
        return AppColors.warning;
      case MessageType.info:
        return AppColors.info;
    }
  }

  IconData get _defaultIcon {
    switch (type) {
      case MessageType.success:
        return Icons.check_circle_outline;
      case MessageType.error:
        return Icons.error_outline;
      case MessageType.warning:
        return Icons.warning_amber_outlined;
      case MessageType.info:
        return Icons.info_outline;
    }
  }

  // ── Helper pour afficher en SnackBar ──────────────────────
  static void show(
    BuildContext context, {
    required String message,
    MessageType type = MessageType.info,
  }) {
    Color bg;
    IconData icon;

    switch (type) {
      case MessageType.success:
        bg = AppColors.success;
        icon = Icons.check_circle_outline;
        break;
      case MessageType.error:
        bg = AppColors.error;
        icon = Icons.error_outline;
        break;
      case MessageType.warning:
        bg = AppColors.warning;
        icon = Icons.warning_amber_outlined;
        break;
      case MessageType.info:
        bg = AppColors.info;
        icon = Icons.info_outline;
        break;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spaceLarge),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? _defaultIcon, color: _color, size: 20),
          const SizedBox(width: AppTheme.spaceMedium),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: AppTheme.textMedium,
                color: _color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}