import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class AutomatisationScreen extends StatefulWidget {
  const AutomatisationScreen({super.key});

  @override
  State<AutomatisationScreen> createState() => _AutomatisationScreenState();
}

class _AutomatisationScreenState extends State<AutomatisationScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _configs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/auto-generate-config.php');
      final d = data['data'] ?? data;
      _configs = (d['configs'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editConfig(Map<String, dynamic> config) async {
    final coverageCtrl = TextEditingController(
        text: (config['min_coverage_days'] ?? '').toString());
    final restockCtrl = TextEditingController(
        text: (config['restock_days'] ?? '').toString());
    final maxCtrl = TextEditingController(
        text: (config['max_generate'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la règle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${config['site_name']} - ${config['profile_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              TextField(
                controller: coverageCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Couverture min (jours)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: restockCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Restock (jours)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Max génération'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    try {
      await _api.post('/api/auto-generate-config.php', {
        'action': 'update_config',
        'config_id': config['id'],
        'min_coverage_days': int.tryParse(coverageCtrl.text) ?? 3,
        'restock_days': int.tryParse(restockCtrl.text) ?? 3,
        'max_generate': int.tryParse(maxCtrl.text) ?? 50,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteConfig(Map<String, dynamic> config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette règle ?'),
        content: Text(
            '${config['site_name']} - ${config['profile_name']} sera supprimé.'),
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
      await _api.post('/api/auto-generate-config.php', {
        'action': 'delete_config',
        'config_id': config['id'],
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _toggleConfig(Map<String, dynamic> config, bool value) async {
    final id = config['id'];
    if (id == null) return;
    setState(() => config['enabled'] = value ? 1 : 0);
    try {
      await _api.post('/api/auto-generate-config.php', {
        'action': 'update_config',
        'config_id': id,
        'enabled': value,
      });
    } catch (e) {
      if (mounted) {
        setState(() => config['enabled'] = value ? 0 : 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatisation'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _configs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_mode, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Aucune configuration automatique'),
                      SizedBox(height: 4),
                      Text('Configurez la génération automatique de tickets',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _configs.length,
                    itemBuilder: (ctx, i) {
                      final c = _configs[i];
                      final enabled = c['enabled'] == true || c['enabled'] == 1;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            Icons.auto_mode,
                            color: enabled ? AppTheme.success : Colors.grey,
                          ),
                          title: Text(
                              '${c['site_name'] ?? ''} - ${c['profile_name'] ?? ''}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                              'Couverture: ${c['min_coverage_days'] ?? '-'}j  '
                              'Restock: ${c['restock_days'] ?? '-'}j  '
                              'Max: ${c['max_generate'] ?? '-'}',
                              style: const TextStyle(fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: enabled,
                                onChanged: (v) => _toggleConfig(c, v),
                                activeThumbColor: AppTheme.success,
                              ),
                              PopupMenuButton(
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'edit', child: Text('Modifier')),
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Supprimer',
                                          style: TextStyle(
                                              color: AppTheme.danger))),
                                ],
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    _editConfig(c);
                                  } else if (action == 'delete') {
                                    _deleteConfig(c);
                                  }
                                },
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
