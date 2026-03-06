import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../services/api_client.dart';
import '../../widgets/site_selector.dart';
import 'profile_form_screen.dart';

class ProfilesListScreen extends StatefulWidget {
  final Site? site;
  const ProfilesListScreen({super.key, this.site});

  @override
  State<ProfilesListScreen> createState() => _ProfilesListScreenState();
}

class _ProfilesListScreenState extends State<ProfilesListScreen> {
  final _service = MikhmonService();
  final _api = ApiClient();
  Site? _site;
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site != null) _load();
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() => _loading = true);
    try {
      final data = await _service.fetchProfiles(_site!.id);
      _profiles = (data['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(Map<String, dynamic> profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le profil ?'),
        content: Text('Le profil "${profile['name']}" sera désactivé.'),
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
      await _api.post('/api/profiles.php', {
        'action': 'delete',
        'profile_id': profile['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profil supprimé'),
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
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profils')),
        body: SiteSelector(onSelect: (s) {
          setState(() => _site = s);
          _load();
        }),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profils'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => ProfileFormScreen(siteId: _site!.id)),
          );
          if (created == true) _load();
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(child: Text('Aucun profil'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _profiles.length,
                    itemBuilder: (ctx, i) {
                      final p = _profiles[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading:
                              const Icon(Icons.wifi, color: AppTheme.primary),
                          title: Text(p['name'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              'Débit: ${p['rate-limit'] ?? p['rate_limit'] ?? '-'}\n'
                              'Durée: ${p['limit_uptime'] ?? p['limit-uptime'] ?? '-'}',
                              style: const TextStyle(fontSize: 12)),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                  value: 'edit', child: Text('Modifier')),
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
                                      builder: (_) => ProfileFormScreen(
                                          siteId: _site!.id, profile: p)),
                                ).then((ok) {
                                  if (ok == true) _load();
                                });
                              } else if (action == 'delete') {
                                _delete(p);
                              }
                            },
                          ),
                          isThreeLine: true,
                          onTap: () {
                            Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ProfileFormScreen(
                                      siteId: _site!.id, profile: p)),
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
