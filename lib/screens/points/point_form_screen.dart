import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
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
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;
  String _type = 'vendeur';
  bool _isActive = true;
  bool _loading = false;

  bool get isEdit => widget.point != null;

  @override
  void initState() {
    super.initState();
    final p = widget.point;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _contactNameCtrl = TextEditingController(text: p?.contactName ?? '');
    _contactPhoneCtrl = TextEditingController(text: p?.contactPhone ?? '');
    _type = p?.type ?? 'vendeur';
    _isActive = p?.isActive ?? true;
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

      if (mounted) {
        if (result['success'] == true) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['error'] ?? 'Erreur'),
                backgroundColor: AppTheme.danger),
          );
        }
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
              const SizedBox(height: 20),
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
    super.dispose();
  }
}
