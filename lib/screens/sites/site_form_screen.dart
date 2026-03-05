import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/site_service.dart';
import '../../utils/constants.dart';

class SiteFormScreen extends StatefulWidget {
  final Site? site; // null = create, non-null = edit
  const SiteFormScreen({super.key, this.site});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SiteService();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  String _typeActivite = 'other';
  String _currency = 'XOF';
  bool _loading = false;

  bool get isEdit => widget.site != null;

  @override
  void initState() {
    super.initState();
    final s = widget.site;
    _nomCtrl = TextEditingController(text: s?.nom ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _ipCtrl = TextEditingController(text: s?.routerIp ?? '');
    _portCtrl = TextEditingController(text: '${s?.routerPort ?? 8728}');
    _userCtrl = TextEditingController(text: s?.routerUser ?? 'admin');
    _passCtrl = TextEditingController(text: s?.routerPassword ?? '');
    _typeActivite = s?.typeActivite ?? 'other';
    _currency = s?.currency ?? 'XOF';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final data = {
        'nom': _nomCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'router_ip': _ipCtrl.text.trim(),
        'router_port': int.tryParse(_portCtrl.text) ?? 8728,
        'router_user': _userCtrl.text.trim(),
        'router_password': _passCtrl.text,
        'type_activite': _typeActivite,
        'currency': _currency,
        if (isEdit) 'site_id': widget.site!.id,
      };

      final result = await _service.createSite(data);
      if (mounted) {
        if (result['success'] == true) {
          context.read<SiteProvider>().fetchSites();
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEdit ? 'Site modifié' : 'Site créé')),
          );
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
      appBar: AppBar(title: Text(isEdit ? 'Modifier le site' : 'Nouveau site')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nomCtrl,
                decoration: const InputDecoration(labelText: 'Nom du site *'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ipCtrl,
                decoration: const InputDecoration(
                    labelText: 'IP Routeur *', hintText: '192.168.1.1'),
                validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _portCtrl,
                      decoration: const InputDecoration(labelText: 'Port API'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _userCtrl,
                      decoration: const InputDecoration(labelText: 'Utilisateur'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Mot de passe routeur'),
                obscureText: true,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _typeActivite,
                decoration: const InputDecoration(labelText: "Type d'activité"),
                items: AppConstants.siteActivities.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) => setState(() => _typeActivite = v ?? 'other'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Devise'),
                items: const [
                  DropdownMenuItem(value: 'XOF', child: Text('XOF (FCFA)')),
                  DropdownMenuItem(value: 'XAF', child: Text('XAF (FCFA)')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'XOF'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Enregistrer' : 'Créer le site'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
