import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class HotspotUsersScreen extends StatefulWidget {
  final Site site;
  const HotspotUsersScreen({super.key, required this.site});

  @override
  State<HotspotUsersScreen> createState() => _HotspotUsersScreenState();
}

class _HotspotUsersScreenState extends State<HotspotUsersScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchHotspotUsers(widget.site.id);
      _users = (data['users'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _users;
    final s = _search.toLowerCase();
    return _users
        .where((u) =>
            (u['name'] ?? '').toString().toLowerCase().contains(s) ||
            (u['profile'] ?? '').toString().toLowerCase().contains(s))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Utilisateurs Hotspot (${_users.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('Aucun utilisateur'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final u = _filtered[i];
                          final disabled = u['disabled'] == 'true' ||
                              u['disabled'] == true;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: disabled
                                  ? Colors.grey.withValues(alpha: 0.3)
                                  : AppTheme.primary.withValues(alpha: 0.15),
                              child: Icon(
                                disabled ? Icons.block : Icons.person,
                                color: disabled ? Colors.grey : AppTheme.primary,
                                size: 20,
                              ),
                            ),
                            title: Text(u['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                                'Profil: ${u['profile'] ?? '-'}  ${u['uptime'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500)),
                            trailing: PopupMenuButton(
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'remove',
                                    child: Text('Supprimer',
                                        style:
                                            TextStyle(color: AppTheme.danger))),
                              ],
                              onSelected: (action) async {
                                if (action == 'remove') {
                                  await _service.removeHotspotUser(
                                      widget.site.id, u['.id'] ?? '');
                                  _load();
                                }
                              },
                            ),
                            dense: true,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
