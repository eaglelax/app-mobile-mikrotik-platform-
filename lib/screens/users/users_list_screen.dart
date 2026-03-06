import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';
import 'user_form_screen.dart';
import 'user_features_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/users-bulk.php', {'action': 'list'});
      _users = (data['users'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet utilisateur ?'),
        content: Text('L\'utilisateur "${user['name']}" sera supprimé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/api/users-bulk.php', {
        'action': 'delete',
        'ids': [user['id']],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Utilisateur supprimé'),
              backgroundColor: AppTheme.success),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const UserFormScreen()),
          );
          if (created == true) _load();
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Aucun utilisateur'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _users.length,
                    itemBuilder: (ctx, i) {
                      final u = _users[i];
                      final isAdmin = u['role'] == 'admin';
                      final isActive = u['status'] == 'active';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAdmin
                                ? AppTheme.accent.withValues(alpha: 0.2)
                                : AppTheme.primary.withValues(alpha: 0.15),
                            child: Text(
                              (u['name'] ?? 'U')
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                  color: isAdmin
                                      ? AppTheme.accent
                                      : AppTheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(u['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Icon(Icons.circle,
                                  size: 8,
                                  color: isActive
                                      ? AppTheme.success
                                      : Colors.grey),
                            ],
                          ),
                          subtitle: Text(u['email'] ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500)),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Modifier')),
                              const PopupMenuItem(
                                  value: 'features',
                                  child: Text('Permissions')),
                              const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Supprimer',
                                      style:
                                          TextStyle(color: AppTheme.danger))),
                            ],
                            onSelected: (action) {
                              if (action == 'edit') {
                                Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          UserFormScreen(user: u)),
                                ).then((ok) {
                                  if (ok == true) _load();
                                });
                              } else if (action == 'features') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          UserFeaturesScreen(user: u)),
                                );
                              } else if (action == 'delete') {
                                _deleteUser(u);
                              }
                            },
                          ),
                          onTap: () {
                            Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => UserFormScreen(user: u)),
                            ).then((ok) {
                              if (ok == true) _load();
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
