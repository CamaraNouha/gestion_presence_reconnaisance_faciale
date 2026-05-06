// ============================================================
// MES MODULES — Liste des modules de l'étudiant
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
//import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/module_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';

class MyModulesScreen extends StatefulWidget {
  const MyModulesScreen({super.key});

  @override
  State<MyModulesScreen> createState() => _MyModulesScreenState();
}

class _MyModulesScreenState extends State<MyModulesScreen> {
  bool _loading = true;
  List<dynamic> _modules = [];

  @override
  void initState() {
    super.initState();
    _loadModules();
  }

  Future<void> _loadModules() async {
    setState(() => _loading = true);
    try {
      _modules = await ApiService.getMyModules();
    } catch (e) {
      if (mounted) {
        MessageBox.show(
          context,
          message: 'Erreur de chargement',
          type: MessageType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Couleur selon position (visuel) ───────────────────────
  Color _moduleColor(int index) {
    final colors = [
      AppColors.primary,
      AppColors.professeur,
      AppColors.etudiant,
      AppColors.warning,
      AppColors.admin,
      AppColors.info,
    ];
    return colors[index % colors.length];
  }

  // ── Icône selon position ──────────────────────────────────
  IconData _moduleIcon(int index) {
    final icons = [
      Icons.psychology,
      Icons.code,
      Icons.calculate,
      Icons.science,
      Icons.book,
      Icons.lightbulb,
    ];
    return icons[index % icons.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.etudiant,
        title: const Text('Mes Modules'),
        elevation: 0,
      ),
      body: _loading
          ? const LoadingInline()
          : Column(
              children: [
                // ── Header info ──────────────────────────────
                Container(
                  color: AppColors.etudiant,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_modules.length} module(s) inscrit(s)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Liste ────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.etudiant,
                    onRefresh: _loadModules,
                    child: _modules.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.book_outlined,
                                title: 'Aucun module',
                                message:
                                    'L\'administrateur ne vous a inscrit à aucun module pour l\'instant',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _modules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final m = _modules[i];
                              final prof = m['professeur'];
                              final profName = prof != null
                                  ? 'Pr. ${prof['prenom']} ${prof['nom']}'
                                  : 'Non assigné';

                              return ModuleTile(
                                nom: m['nom'] ?? '',
                                code: m['code'] ?? '',
                                semestre: m['semestre'],
                                profNom: profName,
                                icon: _moduleIcon(i),
                                color: _moduleColor(i),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}