import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class ProfileFormScreen extends StatefulWidget {
  final int siteId;
  final Map<String, dynamic>? profile;

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

  InputDecoration _inputDeco(String label, IconData icon, bool isDark, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
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
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
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
                    _isEdit ? 'Modifier le profil' : 'Nouveau profil',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Basic info
                      Text('INFORMATIONS DE BASE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              style: TextStyle(color: textColor),
                              decoration: _inputDeco('Nom du profil', Icons.wifi, isDark),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _priceCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor),
                              decoration: _inputDeco('Prix du ticket (FCFA)', Icons.payments_outlined, isDark),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _rateLimitCtrl,
                              style: TextStyle(color: textColor),
                              decoration: _inputDeco('Débit (rate-limit)', Icons.speed, isDark, hint: 'Ex: 2M/2M'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Session & Validity
                      Text('SESSION & VALIDITÉ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _uptimeCtrl,
                              style: TextStyle(color: textColor),
                              decoration: _inputDeco('Durée de session (limit-uptime)', Icons.timer_outlined, isDark, hint: 'Ex: 1h, 30m, 1d'),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _validityCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: textColor),
                                    decoration: _inputDeco('Validité', Icons.calendar_today, isDark),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 120,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _validityUnit,
                                    dropdownColor: cardColor,
                                    style: TextStyle(color: textColor, fontSize: 14),
                                    decoration: _inputDeco('Unité', Icons.access_time, isDark),
                                    items: const [
                                      DropdownMenuItem(value: 'minutes', child: Text('Min')),
                                      DropdownMenuItem(value: 'hours', child: Text('Heures')),
                                      DropdownMenuItem(value: 'days', child: Text('Jours')),
                                    ],
                                    onChanged: (v) => setState(() => _validityUnit = v ?? 'days'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Advanced
                      Text('OPTIONS AVANCÉES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor, letterSpacing: 0.8)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _sharedCtrl,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor),
                              decoration: _inputDeco('Utilisateurs partagés', Icons.group, isDark),
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _expiredMode,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor, fontSize: 14),
                              decoration: _inputDeco('Mode expiration', Icons.timelapse, isDark),
                              items: const [
                                DropdownMenuItem(value: 'remove_record', child: Text('Supprimer')),
                                DropdownMenuItem(value: 'notice_only', child: Text('Notifier seulement')),
                              ],
                              onChanged: (v) => setState(() => _expiredMode = v ?? 'remove_record'),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Submit
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _submitting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                    SizedBox(width: 10),
                                    Text('Enregistrement...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(_isEdit ? Icons.save : Icons.add, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_isEdit ? 'Enregistrer' : 'Créer le profil', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  ],
                                ),
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
}
