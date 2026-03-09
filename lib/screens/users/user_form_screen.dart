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

  InputDecoration _inputDeco(String label, IconData icon, bool isDark, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: isDark ? AppTheme.darkCard : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.danger, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.danger, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final shadow = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEdit ? 'Modifier utilisateur' : 'Nouvel utilisateur',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
                  ),
                ],
              ),
            ),

            // Form body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Informations section
                      Text('Informations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: _inputDeco('Nom *', Icons.person_outline, isDark),
                              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: _inputDeco('Email *', Icons.email_outlined, isDark),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v != null && v.contains('@') ? null : 'Email invalide',
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtrl,
                              decoration: _inputDeco(
                                isEdit ? 'Nouveau mot de passe' : 'Mot de passe *',
                                Icons.lock_outline,
                                isDark,
                                hint: isEdit ? 'Laisser vide pour ne pas changer' : null,
                              ),
                              obscureText: true,
                              validator: isEdit
                                  ? null
                                  : (v) => v != null && v.length >= 6 ? null : 'Minimum 6 caractères',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Rôle & Statut section
                      Text('Rôle & Statut', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _role,
                              decoration: _inputDeco('Rôle', Icons.admin_panel_settings_outlined, isDark),
                              dropdownColor: cardColor,
                              items: const [
                                DropdownMenuItem(value: 'user', child: Text('Utilisateur')),
                                DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                              ],
                              onChanged: (v) => setState(() => _role = v ?? 'user'),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: _isActive ? AppTheme.success.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.power_settings_new, size: 18, color: _isActive ? AppTheme.success : Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text('Compte actif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor)),
                                ),
                                Switch.adaptive(
                                  value: _isActive,
                                  onChanged: (v) => setState(() => _isActive = v),
                                  activeTrackColor: AppTheme.success,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _loading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(isEdit ? 'Enregistrer' : 'Créer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
