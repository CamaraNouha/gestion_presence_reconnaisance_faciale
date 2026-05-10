// ============================================================
// LISTE DES MODULES — Vue Admin
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/module_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';
import 'create_module_screen.dart';
import 'enroll_students_screen.dart';

class ModulesListScreen extends StatefulWidget {
  const ModulesListScreen({super.key});

  @override
  State<ModulesListScreen> createState() => _ModulesListScreenState();
}

class _ModulesListScreenState extends State<ModulesListScreen> {
  bool _loading = true;
  List<dynamic> _modules = [];
  List<dynamic> _profs = [];
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      _modules = await ApiService.getAllModules();
      _profs = await ApiService.getProfessors();
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

  // ── Récupère le nom du prof par ID ────────────────────────
  String _getProfName(String? profId) {
    if (profId == null) return 'Non assigné';
    final prof = _profs.firstWhere(
      (p) => p['id'] == profId,
      orElse: () => null,
    );
    if (prof == null) return 'Non assigné';
    return 'Pr. ${prof['prenom']} ${prof['nom']}';
  }

  // ── Liste filtrée ─────────────────────────────────────────
  List<dynamic> get _filteredModules {
    if (_search.isEmpty) return _modules;
    final q = _search.toLowerCase();
    return _modules.where((m) {
      final nom = (m['nom'] ?? '').toString().toLowerCase();
      final code = (m['code'] ?? '').toString().toLowerCase();
      return nom.contains(q) || code.contains(q);
    }).toList();
  }

  // ── Suppression module ────────────────────────────────────
  Future<void> _deleteModule(Map<String, dynamic> module) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer le module ${module['nom']} ?\n\nLes inscriptions seront aussi supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteModule(module['id']);
      if (!mounted) return;
      MessageBox.show(
        context,
        message: 'Module supprimé',
        type: MessageType.success,
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    }
  }

  // ── Aller vers création ───────────────────────────────────
  Future<void> _goToCreate() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateModuleScreen(),
      ),
    );
    if (result == true) _loadData();
  }

  // ── Aller vers inscriptions ───────────────────────────────
  Future<void> _goToEnroll(Map<String, dynamic> module) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnrollStudentsScreen(
          moduleId: module['id'],
          moduleName: module['nom'] ?? '',
        ),
      ),
    );
  }

  // ── Menu d'actions sur un module ──────────────────────────
  void _showModuleActions(Map<String, dynamic> module) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.people_outline,
                color: AppColors.admin,
              ),
              title: const Text('Inscrire des étudiants'),
              subtitle: const Text('Gérer les inscriptions'),
              onTap: () {
                Navigator.pop(ctx);
                _goToEnroll(module);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.error,
              ),
              title: const Text(
                'Supprimer le module',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteModule(module);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        title: const Text('Modules'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToCreate,
        backgroundColor: AppColors.admin,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nouveau',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const LoadingInline()
          : Column(
              children: [
                // ── Barre de recherche ───────────────────────
                Container(
                  color: AppColors.admin,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un module...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                    ),
                  ),
                ),

                // ── Liste ────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.admin,
                    onRefresh: _loadData,
                    child: _filteredModules.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.book_outlined,
                                title: 'Aucun module',
                                message:
                                    'Créez votre premier module avec le bouton "+"',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                16, 16, 16, 100),
                            itemCount: _filteredModules.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final m = _filteredModules[i];
                              return ModuleTile(
                                nom: m['nom'] ?? '',
                                code: m['code'] ?? '',
                                semestre: m['semestre'],
                                profNom: _getProfName(m['professeur_id']),
                                icon: Icons.book_outlined,
                                color: AppColors.primary,
                                onTap: () => _showModuleActions(m),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    color: AppColors.textGrey,
                                  ),
                                  onPressed: () => _showModuleActions(m),
                                ),
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