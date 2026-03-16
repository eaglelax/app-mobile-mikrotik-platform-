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

  // Quotas & Features
  late final TextEditingController _maxSitesCtrl;
  late final TextEditingController _maxVpnCtrl;
  late final TextEditingController _maxPointsCtrl;
  bool _featureMikhmon = false;
  bool _featureStatistics = false;
  bool _featureAutogenerate = false;
  bool _loadingFeatures = false;

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
    _maxSitesCtrl = TextEditingController(text: '1');
    _maxVpnCtrl = TextEditingController(text: '0');
    _maxPointsCtrl = TextEditingController(text: '0');
    if (isEdit) _loadFeatures();
  }

  Future<void> _loadFeatures() async {
    setState(() => _loadingFeatures = true);
    try {
      final result = await _api.post('/api/users-bulk.php', {
        'action': 'get-features',
        'user_id': widget.user!['id'],
      });
      if (mounted && result['features'] != null) {
        final f = result['features'];
        setState(() {
          _maxSitesCtrl.text = '${f['max_sites'] ?? 1}';
          _maxVpnCtrl.text = '${f['max_vpn'] ?? 0}';
          _maxPointsCtrl.text = '${f['max_points'] ?? 0}';
          _featureMikhmon = f['feature_mikhmon'] == true || f['feature_mikhmon'] == 1;
          _featureStatistics = f['feature_statistics'] == true || f['feature_statistics'] == 1;
          _featureAutogenerate = f['feature_autogenerate'] == true || f['feature_autogenerate'] == 1;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingFeatures = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      // 1. Save user info
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

      if (mounted && result['success'] == true) {
        // 2. Save features/quotas
        final userId = isEdit ? widget.user!['id'] : result['user_id'];
        if (userId != null) {
          try {
            await _api.post('/api/users-bulk.php', {
              'action': 'update-features',
              'user_id': userId,
              'max_sites': int.tryParse(_maxSitesCtrl.text) ?? 1,
              'max_vpn': int.tryParse(_maxVpnCtrl.text) ?? 0,
              'max_points': int.tryParse(_maxPointsCtrl.text) ?? 0,
              'feature_mikhmon': _featureMikhmon,
              'feature_statistics': _featureStatistics,
              'feature_autogenerate': _featureAutogenerate,
            });
          } catch (_) {}
        }
        if (!mounted) return;
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur'), backgroundColor: AppTheme.danger),
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
                              style: TextStyle(color: textColor),
                              validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: _inputDeco('Email *', Icons.email_outlined, isDark),
                              style: TextStyle(color: textColor),
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
                              style: TextStyle(color: textColor),
                              obscureText: true,
                              validator: isEdit
                                  ? null
                                  : (v) => v != null && v.length >= 6 ? null : 'Minimum 6 caracteres',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Role & Statut
                      Text('Role & Statut', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _role,
                              decoration: _inputDeco('Role', Icons.admin_panel_settings_outlined, isDark),
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor, fontSize: 16),
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
                                  width: 34, height: 34,
                                  decoration: BoxDecoration(
                                    color: _isActive ? AppTheme.success.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.power_settings_new, size: 18, color: _isActive ? AppTheme.success : Colors.grey),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text('Compte actif', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor))),
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

                      const SizedBox(height: 20),

                      // Quotas section
                      Text('Quotas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 4),
                      Text('0 = desactive, 999 = illimite', style: TextStyle(fontSize: 11, color: subtitleColor)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: _loadingFeatures
                            ? const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                            : Column(
                                children: [
                                  _quotaRow('Sites max', Icons.router_outlined, _maxSitesCtrl, textColor, isDark),
                                  const SizedBox(height: 14),
                                  _quotaRow('Tunnels VPN max', Icons.vpn_lock_outlined, _maxVpnCtrl, textColor, isDark),
                                  const SizedBox(height: 14),
                                  _quotaRow('Points de vente max', Icons.store_outlined, _maxPointsCtrl, textColor, isDark),
                                ],
                              ),
                      ),

                      const SizedBox(height: 20),

                      // Features section
                      Text('Fonctionnalites', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: _loadingFeatures
                            ? const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))))
                            : Column(
                                children: [
                                  _featureToggle('Mikhmon', 'Dashboard routeur, vouchers, ventes', Icons.dashboard_outlined, AppTheme.accent, _featureMikhmon, (v) => setState(() => _featureMikhmon = v), textColor, subtitleColor),
                                  Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                  _featureToggle('Statistiques', 'Rapports, graphiques, exports', Icons.bar_chart_rounded, AppTheme.info, _featureStatistics, (v) => setState(() => _featureStatistics = v), textColor, subtitleColor),
                                  Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                                  _featureToggle('Auto-generation', 'Generation automatique de tickets', Icons.auto_awesome, AppTheme.success, _featureAutogenerate, (v) => setState(() => _featureAutogenerate = v), textColor, subtitleColor),
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
                              : Text(isEdit ? 'Enregistrer' : 'Creer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      const SizedBox(height: 24),
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

  Widget _quotaRow(String label, IconData icon, TextEditingController ctrl, Color textColor, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor))),
        SizedBox(
          width: 80,
          height: 42,
          child: TextFormField(
            controller: ctrl,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featureToggle(String title, String subtitle, IconData icon, Color color, bool value, ValueChanged<bool> onChanged, Color textColor, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _maxSitesCtrl.dispose();
    _maxVpnCtrl.dispose();
    _maxPointsCtrl.dispose();
    super.dispose();
  }
}
