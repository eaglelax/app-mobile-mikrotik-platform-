import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../services/gerant_service.dart';
import '../../services/point_service_api.dart';

class PointFormScreen extends StatefulWidget {
  final int siteId;
  final Point? point; // null = create
  const PointFormScreen({super.key, required this.siteId, this.point});

  @override
  State<PointFormScreen> createState() => _PointFormScreenState();
}

class _PointFormScreenState extends State<PointFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = PointServiceApi();
  final _gerantService = GerantService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _gerantPasswordCtrl;
  String _type = 'vendeur';
  bool _isActive = true;
  bool _loading = false;
  bool _createGerant = false;

  // Existing gerant info (for edit mode)
  List<Map<String, dynamic>> _gerants = [];
  bool _loadingGerants = false;

  bool get isEdit => widget.point != null;

  @override
  void initState() {
    super.initState();
    final p = widget.point;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _contactNameCtrl = TextEditingController(text: p?.contactName ?? '');
    _contactPhoneCtrl = TextEditingController(text: p?.contactPhone ?? '');
    _gerantPasswordCtrl = TextEditingController();
    _type = p?.type ?? 'vendeur';
    _isActive = p?.isActive ?? true;
    if (isEdit) _loadGerants();
  }

  Future<void> _loadGerants() async {
    setState(() => _loadingGerants = true);
    try {
      _gerants = await _gerantService.fetchByPoint(widget.point!.id);
    } catch (_) {}
    if (mounted) setState(() => _loadingGerants = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final data = {
        'site_id': widget.siteId,
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'description': _descCtrl.text.trim(),
        'contact_name': _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
        'is_active': _isActive,
      };

      final result = isEdit
          ? await _service.update(widget.point!.id, data)
          : await _service.create(data);

      if (mounted && result['success'] == true) {
        // Create gerant if requested
        if (_createGerant && _gerantPasswordCtrl.text.trim().isNotEmpty) {
          final pointId = isEdit ? widget.point!.id : (result['id'] as int);
          try {
            final gerantResult = await _gerantService.create(
              pointId: pointId,
              password: _gerantPasswordCtrl.text.trim(),
              name: _contactNameCtrl.text.trim().isNotEmpty
                  ? _contactNameCtrl.text.trim()
                  : null,
            );
            if (mounted && gerantResult['success'] == true) {
              await _showGerantCreated(gerantResult);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Point créé, mais erreur gérant: $e'),
                    backgroundColor: AppTheme.warning),
              );
            }
          }
        }
        if (mounted) Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['error'] ?? 'Erreur'),
              backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _showGerantCreated(Map<String, dynamic> result) async {
    final username = result['username'] ?? '';
    final password = result['password'] ?? '';
    if (username.isEmpty) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compte gérant créé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Identifiants du gérant:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _CopyableField(label: 'Utilisateur', value: username),
            const SizedBox(height: 8),
            _CopyableField(label: 'Mot de passe', value: password),
            const SizedBox(height: 12),
            Text('Notez ces identifiants, le mot de passe ne sera plus visible.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Future<void> _resetGerantPassword(Map<String, dynamic> gerant) async {
    final ctrl = TextEditingController();
    final newPwd = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset - ${gerant['name'] ?? gerant['username']}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nouveau mot de passe',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Valider')),
        ],
      ),
    );
    if (newPwd == null || newPwd.isEmpty) return;
    try {
      await _gerantService.resetPassword(gerant['id'] as int, newPwd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Mot de passe réinitialisé'),
              backgroundColor: AppTheme.success),
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
      appBar: AppBar(title: Text(isEdit ? 'Modifier le point' : 'Nouveau point')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom *'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'vendeur', child: Text('Vendeur')),
                  DropdownMenuItem(value: 'zone', child: Text('Zone')),
                  DropdownMenuItem(value: 'partenaire', child: Text('Partenaire')),
                  DropdownMenuItem(value: 'lieu', child: Text('Lieu')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'vendeur'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactNameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du contact'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _contactPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Actif'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeThumbColor: AppTheme.success,
              ),

              // --- Gerant section ---
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  const Text('Compte Gérant',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),

              if (isEdit && _loadingGerants)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),

              // Show existing gerants in edit mode
              if (isEdit && !_loadingGerants && _gerants.isNotEmpty)
                ..._gerants.map((g) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (g['status'] == 'active'
                                  ? AppTheme.success
                                  : AppTheme.danger)
                              .withValues(alpha: 0.15),
                          child: Icon(Icons.person,
                              color: g['status'] == 'active'
                                  ? AppTheme.success
                                  : AppTheme.danger,
                              size: 20),
                        ),
                        title: Text(g['username'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(g['name'] ?? '',
                            style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.lock_reset, size: 20),
                          tooltip: 'Reset mot de passe',
                          onPressed: () => _resetGerantPassword(g),
                        ),
                      ),
                    )),

              if (isEdit && !_loadingGerants && _gerants.isEmpty)
                Text('Aucun gérant pour ce point.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),

              // Create gerant toggle
              if (!isEdit || _gerants.isEmpty) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Créer un compte gérant'),
                  subtitle: const Text('Permet de gérer ce point de vente',
                      style: TextStyle(fontSize: 12)),
                  value: _createGerant,
                  onChanged: (v) => setState(() => _createGerant = v),
                  activeThumbColor: AppTheme.primary,
                ),
                if (_createGerant) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _gerantPasswordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe du gérant *',
                      border: OutlineInputBorder(),
                      helperText: 'Le nom d\'utilisateur sera généré automatiquement',
                    ),
                    validator: _createGerant
                        ? (v) => v == null || v.length < 4
                            ? 'Min 4 caractères'
                            : null
                        : null,
                  ),
                ],
              ],

              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Enregistrer' : 'Créer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _gerantPasswordCtrl.dispose();
    super.dispose();
  }
}

class _CopyableField extends StatelessWidget {
  final String label;
  final String value;
  const _CopyableField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copié'), duration: const Duration(seconds: 1)),
            );
          },
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
