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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouvel utilisateur'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Username
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom d\'utilisateur',
                        hintText: 'client01',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Requis' : null,
                    ),
                    const SizedBox(height: 14),

                    // Profile dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedProfile,
                      decoration: const InputDecoration(
                        labelText: 'Profil',
                        prefixIcon: Icon(Icons.wifi),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'default', child: Text('default')),
                        ..._profiles
                            .where((p) => p['name'] != 'default')
                            .map((p) => DropdownMenuItem(
                                value: p['name'].toString(),
                                child: Text(p['name'].toString()))),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedProfile = v ?? 'default'),
                    ),
                    const SizedBox(height: 14),

                    // Server dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedServer,
                      decoration: const InputDecoration(
                        labelText: 'Serveur',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('Tous les serveurs')),
                        ..._servers.map((s) =>
                            DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedServer = v ?? 'all'),
                    ),
                    const SizedBox(height: 18),

                    // Advanced options
                    InkWell(
                      onTap: () =>
                          setState(() => _showAdvanced = !_showAdvanced),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                                _showAdvanced
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text('Options avancées',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),

                    if (_showAdvanced) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _timeLimitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Limite de temps',
                          hintText: 'Ex: 1h, 30m, 1d',
                          prefixIcon: Icon(Icons.timer_outlined),
                          helperText: '1h = 1 heure, 30m = 30 min, 1d = 1 jour',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dataLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Limite de données',
                                hintText: 'Quantité',
                                prefixIcon: Icon(Icons.data_usage_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 80,
                            child: DropdownButtonFormField<String>(
                              initialValue: _dataUnit,
                              items: ['KB', 'MB', 'GB']
                                  .map((u) => DropdownMenuItem(
                                      value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _dataUnit = v ?? 'MB'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _commentCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Commentaire',
                          hintText: 'Laisser vide = vc (voucher)',
                          prefixIcon: Icon(Icons.comment_outlined),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Submit button
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
                            : const Icon(Icons.person_add),
                        label: Text(_submitting ? 'Ajout...' : 'Ajouter'),
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
