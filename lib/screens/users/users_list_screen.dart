import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Utilisateurs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
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
                          title: Text(u['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(u['email'] ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdmin)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Admin',
                                      style: TextStyle(
                                          color: AppTheme.accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600)),
                                ),
                              Icon(Icons.circle,
                                  size: 8,
                                  color: isActive
                                      ? AppTheme.success
                                      : Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
