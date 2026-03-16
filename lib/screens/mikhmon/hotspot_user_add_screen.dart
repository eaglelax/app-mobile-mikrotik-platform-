import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class HotspotUserAddScreen extends StatefulWidget {
  final Site site;
  const HotspotUserAddScreen({super.key, required this.site});

  @override
  State<HotspotUserAddScreen> createState() => _HotspotUserAddScreenState();
}

class _HotspotUserAddScreenState extends State<HotspotUserAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = MikhmonService();

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _timeLimitCtrl = TextEditingController();
  final _dataLimitCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  List<Map<String, dynamic>> _profiles = [];
  List<String> _servers = [];
  String _selectedProfile = 'default';
  String _selectedServer = 'all';
  String _dataUnit = 'MB';
  bool _loading = true;
  bool _submitting = false;
  bool _showPassword = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _timeLimitCtrl.dispose();
    _dataLimitCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final profileData = await _service.fetchProfiles(widget.site.id);
      final serverData = await _service.fetchServers(widget.site.id);
      if (mounted) {
        setState(() {
          _profiles =
              (profileData['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
          final serverList = serverData['servers'] as List? ?? [];
          _servers = serverList
              .map((s) => (s is Map ? s['name'] : s).toString())
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final userData = <String, dynamic>{
        'username': _usernameCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'profile': _selectedProfile,
        'server': _selectedServer,
      };
      if (_timeLimitCtrl.text.isNotEmpty) {
        userData['time_limit'] = _timeLimitCtrl.text.trim();
      }
      if (_dataLimitCtrl.text.isNotEmpty) {
        userData['data_limit'] = _dataLimitCtrl.text.trim();
        userData['data_unit'] = _dataUnit;
      }
      if (_commentCtrl.text.isNotEmpty) {
        userData['comment'] = _commentCtrl.text.trim();
      }

      final result = await _service.addHotspotUser(widget.site.id, userData);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Utilisateur ajouté avec succès'),
                backgroundColor: AppTheme.success),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['error'] ?? 'Erreur lors de l\'ajout'),
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

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? AppTheme.darkCard : Colors.white,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
      ),
      helperStyle: TextStyle(
        color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : Colors.grey.shade900;
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: textColor,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouvel utilisateur',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          widget.site.nom,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Main fields container
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark
                                        ? Colors.black.withValues(alpha: 0.2)
                                        : Colors.grey.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Username
                                  TextFormField(
                                    controller: _usernameCtrl,
                                    style: TextStyle(color: textColor),
                                    decoration: _inputDecoration(
                                      label: 'Nom d\'utilisateur',
                                      hint: 'client01',
                                      prefixIcon: Icon(Icons.person_outline,
                                          color: subtitleColor),
                                      isDark: isDark,
                                    ),
                                    validator: (v) => (v == null || v.trim().isEmpty)
                                        ? 'Requis'
                                        : null,
                                  ),
                                  const SizedBox(height: 14),

                                  // Password
                                  TextFormField(
                                    controller: _passwordCtrl,
                                    obscureText: !_showPassword,
                                    style: TextStyle(color: textColor),
                                    decoration: _inputDecoration(
                                      label: 'Mot de passe',
                                      prefixIcon: Icon(Icons.lock_outline,
                                          color: subtitleColor),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: subtitleColor,
                                        ),
                                        onPressed: () => setState(
                                            () => _showPassword = !_showPassword),
                                      ),
                                      isDark: isDark,
                                    ),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? 'Requis' : null,
                                  ),
                                  const SizedBox(height: 14),

                                  // Profile dropdown
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedProfile,
                                    dropdownColor: cardColor,
                                    style: TextStyle(color: textColor, fontSize: 14),
                                    decoration: _inputDecoration(
                                      label: 'Profil',
                                      prefixIcon:
                                          Icon(Icons.wifi, color: subtitleColor),
                                      isDark: isDark,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                          value: 'default',
                                          child: Text('default')),
                                      ..._profiles
                                          .where((p) => p['name'] != 'default')
                                          .map((p) => DropdownMenuItem(
                                              value: p['name'].toString(),
                                              child:
                                                  Text(p['name'].toString()))),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _selectedProfile = v ?? 'default'),
                                  ),
                                  const SizedBox(height: 14),

                                  // Server dropdown
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedServer,
                                    dropdownColor: cardColor,
                                    style: TextStyle(color: textColor, fontSize: 14),
                                    decoration: _inputDecoration(
                                      label: 'Serveur',
                                      prefixIcon: Icon(Icons.dns_outlined,
                                          color: subtitleColor),
                                      isDark: isDark,
                                    ),
                                    items: [
                                      const DropdownMenuItem(
                                          value: 'all',
                                          child: Text('Tous les serveurs')),
                                      ..._servers.map((s) => DropdownMenuItem(
                                          value: s, child: Text(s))),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _selectedServer = v ?? 'all'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Advanced options toggle
                            InkWell(
                              onTap: () => setState(
                                  () => _showAdvanced = !_showAdvanced),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showAdvanced
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: subtitleColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Options avancées',
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (_showAdvanced) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? Colors.black.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.08),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _timeLimitCtrl,
                                      style: TextStyle(color: textColor),
                                      decoration: _inputDecoration(
                                        label: 'Limite de temps',
                                        hint: 'Ex: 1h, 30m, 1d',
                                        prefixIcon: Icon(Icons.timer_outlined,
                                            color: subtitleColor),
                                        helperText:
                                            '1h = 1 heure, 30m = 30 min, 1d = 1 jour',
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _dataLimitCtrl,
                                            keyboardType:
                                                TextInputType.number,
                                            style:
                                                TextStyle(color: textColor),
                                            decoration: _inputDecoration(
                                              label: 'Limite de données',
                                              hint: 'Quantité',
                                              prefixIcon: Icon(
                                                  Icons.data_usage_outlined,
                                                  color: subtitleColor),
                                              isDark: isDark,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 90,
                                          child:
                                              DropdownButtonFormField<String>(
                                            initialValue: _dataUnit,
                                            dropdownColor: cardColor,
                                            style: TextStyle(
                                                color: textColor,
                                                fontSize: 14),
                                            decoration: _inputDecoration(
                                              label: '',
                                              isDark: isDark,
                                            ),
                                            items: ['KB', 'MB', 'GB']
                                                .map((u) => DropdownMenuItem(
                                                    value: u,
                                                    child: Text(u)))
                                                .toList(),
                                            onChanged: (v) => setState(() =>
                                                _dataUnit = v ?? 'MB'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _commentCtrl,
                                      style: TextStyle(color: textColor),
                                      decoration: _inputDecoration(
                                        label: 'Commentaire',
                                        hint: 'Laisser vide = vc (voucher)',
                                        prefixIcon: Icon(
                                            Icons.comment_outlined,
                                            color: subtitleColor),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Submit button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: _submitting ? null : _submit,
                                icon: _submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.person_add,
                                        color: Colors.white),
                                label: Text(
                                  _submitting ? 'Ajout...' : 'Ajouter',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  disabledBackgroundColor:
                                      AppTheme.primary.withValues(alpha: 0.5),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
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
