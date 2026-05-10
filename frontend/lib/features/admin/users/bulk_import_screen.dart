// ============================================================
// IMPORT EN BLOC D'ÉTUDIANTS (Admin)
// ============================================================

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/message_box.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  File? _selectedFile;
  bool _loading = false;
  Map<String, dynamic>? _result;

  // ── Sélectionner un fichier ───────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _result = null; // Reset le résultat précédent
        });
      }
    } catch (e) {
      if (mounted) {
        MessageBox.show(
          context,
          message: 'Erreur lors de la sélection : $e',
          type: MessageType.error,
        );
      }
    }
  }

  // ── Uploader le fichier ───────────────────────────────────
  Future<void> _import() async {
    if (_selectedFile == null) return;

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await ApiService.bulkImportStudents(
        _selectedFile!.path,
      );

      if (!mounted) return;

      setState(() => _result = result);

      MessageBox.show(
        context,
        message: result['message'] ?? 'Import réussi',
        type: MessageType.success,
      );
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = _selectedFile?.path.split('/').last
        ?? _selectedFile?.path.split('\\').last;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        title: const Text('Import en bloc'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Info ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.adminLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.admin,
                        size: 22,
                      ),
                       SizedBox(width: 8),
                       Text(
                        'Format requis',
                        style: TextStyle(
                          fontSize: AppTheme.textMedium,
                          fontWeight: FontWeight.bold,
                          color: AppColors.admin,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fichier CSV ou Excel avec ces colonnes :',
                    style: TextStyle(
                      fontSize: AppTheme.textSmall,
                      color: AppColors.admin,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'nom, prenom, email, apogee, mot_de_passe',
                      style: TextStyle(
                        fontSize: AppTheme.textXSmall,
                        fontFamily: 'monospace',
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Photo non requise (étudiants l\'ajouteront à la 1ère connexion)\n'
                    '• Si mot_de_passe vide → l\'apogée sera utilisé',
                    style: TextStyle(
                      fontSize: AppTheme.textXSmall,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceXLarge),

            // ── Sélection de fichier ─────────────────────────
            const Text(
              'Sélectionner le fichier',
              style: TextStyle(
                fontSize: AppTheme.textSmall,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: AppTheme.spaceSmall),

            GestureDetector(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _selectedFile != null
                      ? AppColors.successLight
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedFile != null
                        ? AppColors.success
                        : AppColors.border,
                    width: _selectedFile != null ? 2 : 1,
                    style: _selectedFile != null
                        ? BorderStyle.solid
                        : BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      size: 48,
                      color: _selectedFile != null
                          ? AppColors.success
                          : AppColors.admin,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? 'Fichier sélectionné'
                          : 'Tape pour sélectionner un fichier',
                      style: TextStyle(
                        fontSize: AppTheme.textMedium,
                        fontWeight: FontWeight.w600,
                        color: _selectedFile != null
                            ? AppColors.success
                            : AppColors.admin,
                      ),
                    ),
                    if (fileName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: AppTheme.textSmall,
                          color: AppColors.textGrey,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text(
                        'CSV ou Excel (.xlsx)',
                        style: TextStyle(
                          fontSize: AppTheme.textXSmall,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppTheme.spaceXLarge),

            // ── Bouton importer ───────────────────────────────
            AppButton(
              text: 'Lancer l\'import',
              icon: Icons.upload,
              loading: _loading,
              onPressed: _selectedFile == null ? null : _import,
              customColor: AppColors.admin,
            ),

            const SizedBox(height: AppTheme.spaceXLarge),

            // ── Résultat ──────────────────────────────────────
            if (_result != null) _buildResult(),
          ],
        ),
      ),
    );
  }

  // ── Affichage du résultat ─────────────────────────────────
  Widget _buildResult() {
    final total = _result!['total'] ?? 0;
    final created = _result!['created'] ?? 0;
    final errors = (_result!['errors'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stats
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: created > 0 ? AppColors.successLight : AppColors.errorLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: created > 0 ? AppColors.success : AppColors.error,
            ),
          ),
          child: Column(
            children: [
              Icon(
                created > 0 ? Icons.check_circle : Icons.error,
                size: 48,
                color: created > 0 ? AppColors.success : AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                'Import terminé',
                style: TextStyle(
                  fontSize: AppTheme.textLarge,
                  fontWeight: FontWeight.bold,
                  color: created > 0 ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStat(
                    label: 'Total',
                    value: '$total',
                    color: AppColors.info,
                  ),
                  _buildStat(
                    label: 'Créés',
                    value: '$created',
                    color: AppColors.success,
                  ),
                  _buildStat(
                    label: 'Erreurs',
                    value: '${errors.length}',
                    color: AppColors.error,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTheme.spaceLarge),

        // Liste des erreurs
        if (errors.isNotEmpty) ...[
          const Text(
            'Erreurs détectées',
            style: TextStyle(
              fontSize: AppTheme.textMedium,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          ...errors.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ligne ${e['ligne']}',
                            style: const TextStyle(
                              fontSize: AppTheme.textXSmall,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e['erreur'] ?? '',
                            style: const TextStyle(
                              fontSize: AppTheme.textSmall,
                              color: AppColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],

        const SizedBox(height: AppTheme.spaceLarge),

        // Bouton retour
        AppButton(
          text: 'Terminer',
          icon: Icons.check,
          onPressed: () => Navigator.pop(context, true),
          style: AppButtonStyle.success,
        ),
      ],
    );
  }

  // ── Stat box ──────────────────────────────────────────────
  Widget _buildStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: AppTheme.textXSmall,
            color: AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}