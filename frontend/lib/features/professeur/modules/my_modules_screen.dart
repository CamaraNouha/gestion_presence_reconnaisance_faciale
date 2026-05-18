// ============================================================
// MES MODULES — Vue Professeur
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/module_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';

class ProfMyModulesScreen extends StatefulWidget {
  const ProfMyModulesScreen({super.key});

  @override
  State<ProfMyModulesScreen> createState() => _ProfMyModulesScreenState();
}

class _ProfMyModulesScreenState extends State<ProfMyModulesScreen> {
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
      _modules = await ApiService.getProfModules();
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

  Color _moduleColor(int i) {
    final colors = [
      AppColors.primary,
      AppColors.professeur,
      AppColors.etudiant,
      AppColors.warning,
      AppColors.admin,
      AppColors.info,
    ];
    return colors[i % colors.length];
  }

  IconData _moduleIcon(int i) {
    final icons = [
      Icons.psychology,
      Icons.code,
      Icons.calculate,
      Icons.science,
      Icons.book,
      Icons.lightbulb,
    ];
    return icons[i % icons.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.professeur,
        title: const Text('Mes Modules'),
        elevation: 0,
      ),
      body: _loading
          ? const LoadingInline()
          : RefreshIndicator(
              color: AppColors.professeur,
              onRefresh: _loadModules,
              child: _modules.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.book_outlined,
                          title: 'Aucun module',
                          message:
                              'Aucun module ne vous est assigné pour l\'instant',
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
                        return ModuleTile(
                          nom: m['nom'] ?? '',
                          code: m['code'] ?? '',
                          semestre: m['semestre'],
                          icon: _moduleIcon(i),
                          color: _moduleColor(i),
                        );
                      },
                    ),
            ),
    );
  }
}