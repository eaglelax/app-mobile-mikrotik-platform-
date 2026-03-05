import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class UserFormScreen extends StatefulWidget {
  final Map<String, dynamic>? user; // null = create
  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  String _role = 'user';
  bool _isActive = true;
  bool _loading = false;

  bool get isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameCtrl = TextEditingController(text: u?['name'] ?? '');
    _emailCtrl = TextEditingController(text: u?['email'] ?? '');
    _passCtrl = TextEditingController();
    _role = u?['role'] ?? 'user';
    _isActive = u?['status'] == 'active' || u == null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final data = {
        'action': isEdit ? 'update' : 'create',
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _role,
        'status': _isActive ? 'active' : 'inactive',
        if (isEdit) 'user_id': widget.user!['id'],
        if (_passCtrl.text.isNotEmpty) 'password': _passCtrl.text,
      };

      final result = await _api.post('/api/users-bulk.php', data);

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
      appBar: AppBar(
          title: Text(isEdit ? 'Modifier utilisateur' : 'Nouvel utilisateur')),
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
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v != null && v.contains('@') ? null : 'Email invalide',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                decoration: InputDecoration(
                  labelText: isEdit ? 'Nouveau mot de passe' : 'Mot de passe *',
                  hintText: isEdit ? 'Laisser vide pour ne pas changer' : null,
                ),
                obscureText: true,
                validator: isEdit
                    ? null
                    : (v) => v != null && v.length >= 6
                        ? null
                        : 'Minimum 6 caractères',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Rôle'),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Utilisateur')),
                  DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'user'),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                title: const Text('Compte actif'),
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
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}
