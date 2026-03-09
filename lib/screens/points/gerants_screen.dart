import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../services/gerant_service.dart';

class GerantsScreen extends StatefulWidget {
  final Point point;
  const GerantsScreen({super.key, required this.point});

  @override
  State<GerantsScreen> createState() => _GerantsScreenState();
}

class _GerantsScreenState extends State<GerantsScreen> {
  final _service = GerantService();
  List<Map<String, dynamic>> _gerants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _gerants = await _service.fetchByPoint(widget.point.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _createGerant() async {
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouveau Gerant'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom (optionnel)',
                  hintText: 'Ex: Mamadou',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  hintText: 'Min. 4 caracteres',
                ),
                validator: (v) =>
                    (v == null || v.length < 4) ? 'Min. 4 caracteres' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, {
                  'name': nameCtrl.text.trim(),
                  'password': passCtrl.text,
                });
              }
            },
            child: const Text('Creer'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final res = await _service.create(
        pointId: widget.point.id,
        password: result['password'],
        name: result['name'],
      );
      if (res['success'] == true && mounted) {
        final gerant = res['gerant'];
        _showCredentials(gerant);
        _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Erreur'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _showCredentials(Map<String, dynamic> gerant) {
    final username = gerant['username'] ?? gerant['email'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gerant cree'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Identifiants de connexion:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _credentialRow('Nom', gerant['name'] ?? ''),
            _credentialRow('Username', username),
            _credentialRow('Point', gerant['point_name'] ?? widget.point.name),
            const SizedBox(height: 12),
            const Text(
              'Notez ces identifiants, le mot de passe ne sera plus visible.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Username: $username'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Username copie')),
              );
            },
            child: const Text('Copier username'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(Map<String, dynamic> gerant) async {
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset - ${gerant['name']}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passCtrl,
            decoration: const InputDecoration(
              labelText: 'Nouveau mot de passe',
              hintText: 'Min. 4 caracteres',
            ),
            validator: (v) =>
                (v == null || v.length < 4) ? 'Min. 4 caracteres' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, passCtrl.text);
              }
            },
            child: const Text('Changer'),
          ),
        ],
      ),
    );

    if (newPass == null) return;

    try {
      final res = await _service.resetPassword(gerant['id'], newPass);
      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe mis a jour'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Erreur'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> gerant) async {
    final newStatus = gerant['status'] == 'active' ? 'inactive' : 'active';
    try {
      final res = await _service.update(gerant['id'], status: newStatus);
      if (res['success'] == true) _load();
    } catch (_) {}
  }

  Future<void> _deleteGerant(Map<String, dynamic> gerant) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le gerant'),
        content: Text('Supprimer "${gerant['name']}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await _service.delete(gerant['id']);
      if (res['success'] == true) {
        _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Erreur'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gerants'),
            Text(widget.point.name,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGerant,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _gerants.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_off,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('Aucun gerant pour ce point'),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _createGerant,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Creer un gerant'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _gerants.length,
                    itemBuilder: (ctx, i) {
                      final g = _gerants[i];
                      final isActive = g['status'] == 'active';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive
                                ? AppTheme.primary.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.15),
                            child: Icon(Icons.person,
                                color: isActive
                                    ? AppTheme.primary
                                    : Colors.grey),
                          ),
                          title: Text(g['name'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            g['email'] ?? '',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isActive
                                      ? AppTheme.success
                                      : Colors.grey)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isActive ? 'Actif' : 'Inactif',
                              style: TextStyle(
                                  color: isActive
                                      ? AppTheme.success
                                      : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                children: [
                                  if (g['last_login'] != null)
                                    _infoRow('Derniere connexion',
                                        g['last_login']),
                                  if (g['created_at'] != null)
                                    _infoRow('Cree le', g['created_at']),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _resetPassword(g),
                                        icon: const Icon(Icons.lock_reset,
                                            size: 18),
                                        label: const Text('Mot de passe',
                                            style: TextStyle(fontSize: 12)),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _toggleStatus(g),
                                        icon: Icon(
                                          isActive
                                              ? Icons.block
                                              : Icons.check_circle,
                                          size: 18,
                                          color: isActive
                                              ? Colors.orange
                                              : AppTheme.success,
                                        ),
                                        label: Text(
                                          isActive
                                              ? 'Desactiver'
                                              : 'Activer',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _deleteGerant(g),
                                        icon: const Icon(Icons.delete,
                                            size: 18, color: AppTheme.danger),
                                        label: const Text('Supprimer',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.danger)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
