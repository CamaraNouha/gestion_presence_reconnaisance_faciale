// ============================================================
// CRÉER UN MODULE — Vue Admin
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/message_box.dart';

class CreateModuleScreen extends StatefulWidget {
  const CreateModuleScreen({super.key});

  @override
  State<CreateModuleScreen> createState() => _CreateModuleScreenState();
}

class _CreateModuleScreenState extends State<CreateModuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  String _semestre = 'S1';
  String _filiere = 'Intelligence Artificielle(IA)';
  String? _profId;

  bool _loading = false;
  bool _loadingProfs = true;
  List<dynamic> _profs = [];

  final List<String> _semestres = [
    'S1', 'S2', 'S3', 'S4', 'S5', 'S6','S7','S8','S9'
  ];

  final List<String> _filieres = [
    'Intelligence Artificielle(IA)', 
    'Génie Informatique(GINF)', 
    'Robotique et Objets connetés(ROC)', 
    'Ingénierie réseaux et sécurité Informatique(IRSI)',
    'Etudes Préparatoires en Sciences de L\'ingénieur(EPSI)'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfs();
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Charge la liste des profs ─────────────────────────────
  Future<void> _loadProfs() async {
    try {
      _profs = await ApiService.getProfessors();
    } catch (e) {
      print('Erreur chargement profs: $e');
    } finally {
      if (mounted) setState(() => _loadingProfs = false);
    }
  }

  // ── Création du module ────────────────────────────────────
  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    if (_profId == null) {
      MessageBox.show(
        context,
        message: 'Veuillez sélectionner un professeur',
        type: MessageType.warning,
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiService.createModule(
        nom: _nomCtrl.text.trim(),
        code: _codeCtrl.text.trim().toUpperCase(),
        semestre: _semestre,
        filiere: _filiere,
        professeurId: _profId!,
      );

      if (!mounted) return;

      MessageBox.show(
        context,
        message: 'Module créé avec succès',
        type: MessageType.success,
      );

      Navigator.pop(context, true);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        title: const Text('Nouveau module'),
        elevation: 0,
      ),
      body: _loadingProfs
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.admin),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLarge),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Info ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.adminLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: AppColors.admin,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Créez un module et assignez-lui un professeur. Vous pourrez ensuite y inscrire des étudiants.',
                              style: TextStyle(
                                fontSize: AppTheme.textSmall,
                                color: AppColors.admin,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceXLarge),

                    // ── Nom ─────────────────────────────────
                    AppTextField(
                      controller: _nomCtrl,
                      label: 'Nom du module',
                      hint: 'Ex: Intelligence Artificielle',
                      icon: Icons.book_outlined,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nom requis'
                          : null,
                    ),

                    const SizedBox(height: AppTheme.spaceMedium),

                    // ── Code ────────────────────────────────
                    AppTextField(
                      controller: _codeCtrl,
                      label: 'Code',
                      hint: 'Ex: IA101',
                      icon: Icons.qr_code,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Code requis'
                          : null,
                    ),

                    const SizedBox(height: AppTheme.spaceLarge),

                    // ── Semestre ────────────────────────────
                    const Text(
                      'Semestre',
                      style: TextStyle(
                        fontSize: AppTheme.textSmall,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _semestres.map((s) {
                          final selected = _semestre == s;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _semestre = s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.admin
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.admin
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: AppTheme.textSmall,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceLarge),

                    // ── Filière ─────────────────────────────
                    const Text(
                      'Filière',
                      style: TextStyle(
                        fontSize: AppTheme.textSmall,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filiere,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _filieres.map((f) {
                            return DropdownMenuItem(
                              value: f,
                              child: Text(f),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _filiere = v);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spaceLarge),

                    // ── Professeur ──────────────────────────
                    const Text(
                      'Professeur assigné',
                      style: TextStyle(
                        fontSize: AppTheme.textSmall,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_profs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_outlined,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aucun professeur disponible. Créez d\'abord un compte professeur.',
                                style: TextStyle(
                                  fontSize: AppTheme.textSmall,
                                  color: AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _profId,
                            hint: const Text('Sélectionner un professeur'),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            items: _profs.map((p) {
                              return DropdownMenuItem<String>(
                                value: p['id'],
                                child: Text(
                                  'Pr. ${p['prenom']} ${p['nom']}',
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() => _profId = v);
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: AppTheme.spaceXLarge),

                    // ── Bouton créer ────────────────────────
                    AppButton(
                      text: 'Créer le module',
                      icon: Icons.check,
                      loading: _loading,
                      onPressed: _profs.isEmpty ? null : _create,
                      customColor: AppColors.admin,
                    ),

                    const SizedBox(height: AppTheme.spaceXLarge),
                  ],
                ),
              ),
            ),
    );
  }
}