// ============================================================
// LISTE DES UTILISATEURS — Vue Admin
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/user_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/message_box.dart';
import '../../../core/widgets/loading_screen.dart';
import 'create_user_screen.dart';

class UsersListScreen extends StatefulWidget {
  final String? initialFilter;

  const UsersListScreen({super.key, this.initialFilter});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  bool _loading = true;
  List<dynamic> _allUsers = [];
  String _filter = 'all'; // 'all', 'etudiant', 'professeur', 'admin'
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _filter = widget.initialFilter!;
    }
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      _allUsers = await ApiService.getAllUsers();
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

  // ── Liste filtrée + recherche ─────────────────────────────
  List<dynamic> get _filteredUsers {
    var users = _allUsers;

    // Filtre par rôle
    if (_filter != 'all') {
      users = users.where((u) => u['role'] == _filter).toList();
    }

    // Recherche
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      users = users.where((u) {
        final nom = (u['nom'] ?? '').toString().toLowerCase();
        final prenom = (u['prenom'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final apogee = (u['apogee'] ?? '').toString().toLowerCase();
        return nom.contains(q) ||
            prenom.contains(q) ||
            email.contains(q) ||
            apogee.contains(q);
      }).toList();
    }

    return users;
  }

  // ── Suppression user ──────────────────────────────────────
  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final role = user['role'];
    String warning = '';

    if (role == 'professeur') {
      warning =
          '\n\n⚠️ Tous ses modules, sessions et présences seront aussi supprimés.';
    } else if (role == 'etudiant') {
      warning =
          '\n\n⚠️ Ses inscriptions et présences seront aussi supprimées.';
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer ${user['prenom']} ${user['nom']} ?$warning\n\nCette action est irréversible.',
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
      await ApiService.deleteUser(user['id']);
      if (!mounted) return;
      MessageBox.show(
        context,
        message: 'Utilisateur supprimé',
        type: MessageType.success,
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      MessageBox.show(
        context,
        message: e.toString().replaceAll('Exception: ', ''),
        type: MessageType.error,
      );
    }
  }

  // ── Création user ─────────────────────────────────────────
  Future<void> _goToCreateUser() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );
    if (result == true) {
      _loadUsers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.admin,
        title: const Text('Utilisateurs'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToCreateUser,
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
                // ── Barre de recherche ──────────────────────
                Container(
                  color: AppColors.admin,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Rechercher...',
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

                // ── Filtres ──────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('Tous', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Étudiants', 'etudiant'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Professeurs', 'professeur'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Admins', 'admin'),
                      ],
                    ),
                  ),
                ),

                // ── Liste ────────────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.admin,
                    onRefresh: _loadUsers,
                    child: _filteredUsers.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              EmptyState(
                                icon: Icons.people_outline,
                                title: 'Aucun utilisateur',
                                message:
                                    'Aucun utilisateur ne correspond aux critères',
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                16, 16, 16, 100),
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final u = _filteredUsers[i];
                              return UserTile(
                                nom: u['nom'] ?? '',
                                prenom: u['prenom'] ?? '',
                                email: u['email'] ?? '',
                                role: u['role'] ?? '',
                                apogee: u['apogee'],
                                onDelete: () => _deleteUser(u),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Filter chip ───────────────────────────────────────────
  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.admin : AppColors.adminLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTheme.textSmall,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.admin,
            ),
          ),
        ),
      ),
    );
  }
}