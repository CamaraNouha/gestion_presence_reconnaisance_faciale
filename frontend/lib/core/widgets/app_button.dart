// ============================================================
// APP BUTTON — Boutons stylisés ENIAD
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

enum AppButtonStyle { primary, secondary, success, danger, outline }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  final Color? customColor;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = true,
    this.customColor,
  });

  // ── Couleur selon le style ────────────────────────────────
  Color get _bgColor {
    if (customColor != null) return customColor!;
    switch (style) {
      case AppButtonStyle.primary:
        return AppColors.primary;
      case AppButtonStyle.secondary:
        return AppColors.textDark;
      case AppButtonStyle.success:
        return AppColors.success;
      case AppButtonStyle.danger:
        return AppColors.error;
      case AppButtonStyle.outline:
        return Colors.transparent;
    }
  }

  Color get _textColor {
    if (style == AppButtonStyle.outline) {
      return customColor ?? AppColors.primary;
    }
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _bgColor,
        foregroundColor: _textColor,
        disabledBackgroundColor: _bgColor.withOpacity(0.5),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spaceLarge,
          horizontal: AppTheme.spaceXLarge,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          side: style == AppButtonStyle.outline
              ? BorderSide(
                  color: customColor ?? AppColors.primary,
                  width: 1.5,
                )
              : BorderSide.none,
        ),
      ),
      child: loading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: _textColor,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: _textColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: AppTheme.textMedium,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
              ],
            ),
    );

    return fullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}