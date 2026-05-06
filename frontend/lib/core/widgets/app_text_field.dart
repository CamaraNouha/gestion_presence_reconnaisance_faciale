// ============================================================
// APP TEXT FIELD — Champ de texte stylisé
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;
  final Widget? suffix;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.textSmall,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSmall),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          maxLines: obscureText ? 1 : maxLines,
          style: const TextStyle(
            fontSize: AppTheme.textMedium,
            color: AppColors.textDark,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, color: AppColors.textGrey, size: 20)
                : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}