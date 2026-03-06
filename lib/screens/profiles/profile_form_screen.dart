import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class ProfileFormScreen extends StatefulWidget {
  final int siteId;
  final Map<String, dynamic>? profile; // null = create

  const ProfileFormScreen({super.key, required this.siteId, this.profile});

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient();

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _uptimeCtrl = TextEditingController();
  final _sharedCtrl = TextEditingController(text: '1');
  final _validityCtrl = TextEditingController(text: '1');
  final _rateLimitCtrl = TextEditingController();

  String _validityUnit = 'days';
  String _expiredMode = 'remove_record';
  bool _submitting = false;

  bool get _isEdit => widget.profile != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.profile!;
      _nameCtrl.text = p['name'] ?? '';
      _priceCtrl.text = (p['ticket_price'] ?? 0).toString();
      _uptimeCtrl.text = p['limit_uptime'] ?? p['limit-uptime'] ?? '';
      _sharedCtrl.text = (p['shared_users'] ?? 1).toString();
      _validityCtrl.text = (p['validity_value'] ?? 1).toString();
      _validityUnit = p['validity_unit'] ?? 'days';
      _expiredMode = p['expired_mode'] ?? 'remove_record';
      _rateLimitCtrl.text = p['rate_limit'] ?? p['rate-limit'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _uptimeCtrl.dispose();
    _sharedCtrl.dispose();
    _validityCtrl.dispose();
    _rateLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final data = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'ticket_price': double.tryParse(_priceCtrl.text) ?? 0,
        'limit_uptime': _uptimeCtrl.text.trim(),
        'shared_users': int.tryParse(_sharedCtrl.text) ?? 1,
        'validity_value': int.tryParse(_validityCtrl.text) ?? 1,
        'validity_unit': _validityUnit,
        'expired_mode': _expiredMode,
        'site_id': widget.siteId,
      };
      if (_rateLimitCtrl.text.isNotEmpty) {
        data['rate_limit'] = _rateLimitCtrl.text.trim();
      }

      if (_isEdit) {
        data['action'] = 'update';
        data['profile_id'] = widget.profile!['id'];
      } else {
        data['action'] = 'create';
      }

      final result = await _api.post('/api/profiles.php', data);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(_isEdit ? 'Profil mis à jour' : 'Profil créé'),
                backgroundColor: AppTheme.success),
          );
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
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le profil' : 'Nouveau profil'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du profil',
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prix du ticket (FCFA)',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _rateLimitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Débit (rate-limit)',
                  hintText: 'Ex: 2M/2M',
                  prefixIcon: Icon(Icons.speed),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _uptimeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Durée de session (limit-uptime)',
                  hintText: 'Ex: 1h, 30m, 1d',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _validityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Validité',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      initialValue: _validityUnit,
                      decoration: const InputDecoration(labelText: 'Unité'),
                      items: const [
                        DropdownMenuItem(value: 'minutes', child: Text('Min')),
                        DropdownMenuItem(value: 'hours', child: Text('Heures')),
                        DropdownMenuItem(value: 'days', child: Text('Jours')),
                      ],
                      onChanged: (v) =>
                          setState(() => _validityUnit = v ?? 'days'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _sharedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Utilisateurs partagés',
                  prefixIcon: Icon(Icons.group),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _expiredMode,
                decoration: const InputDecoration(
                  labelText: 'Mode expiration',
                  prefixIcon: Icon(Icons.timelapse),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'remove_record', child: Text('Supprimer')),
                  DropdownMenuItem(
                      value: 'notice_only', child: Text('Notifier seulement')),
                ],
                onChanged: (v) =>
                    setState(() => _expiredMode = v ?? 'remove_record'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(_isEdit ? Icons.save : Icons.add),
                  label: Text(_submitting
                      ? 'Enregistrement...'
                      : (_isEdit ? 'Enregistrer' : 'Créer le profil')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
