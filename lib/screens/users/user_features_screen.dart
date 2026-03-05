import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class UserFeaturesScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserFeaturesScreen({super.key, required this.user});

  @override
  State<UserFeaturesScreen> createState() => _UserFeaturesScreenState();
}

class _UserFeaturesScreenState extends State<UserFeaturesScreen> {
  final _api = ApiClient();
  Map<String, dynamic> _features = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/users-bulk.php', {
        'action': 'features',
        'user_id': widget.user['id'].toString(),
      });
      _features = Map<String, dynamic>.from(data['features'] ?? {});
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.post('/api/users-bulk.php', {
        'action': 'update_features',
        'user_id': widget.user['id'],
        ..._features,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions sauvegardées')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Permissions - ${widget.user['name']}'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sauver'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Fonctionnalités',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _FeatureSwitch('Mikhmon', 'feature_mikhmon'),
                _FeatureSwitch('Statistiques', 'feature_statistics'),
                _FeatureSwitch('VPN', 'feature_vpn'),
                _FeatureSwitch('Auto-génération', 'feature_autogenerate'),
                const SizedBox(height: 20),
                const Text('Quotas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                _QuotaField('Max Sites', 'max_sites'),
                _QuotaField('Max VPN', 'max_vpn'),
                _QuotaField('Max Auto-gen Configs', 'max_autogen_configs'),
              ],
            ),
    );
  }

  Widget _FeatureSwitch(String label, String key) {
    return SwitchListTile(
      title: Text(label),
      value: _features[key] == true || _features[key] == 1,
      onChanged: (v) => setState(() => _features[key] = v),
      activeColor: AppTheme.success,
    );
  }

  Widget _QuotaField(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: '${_features[key] ?? 0}',
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
        onChanged: (v) => _features[key] = int.tryParse(v) ?? 0,
      ),
    );
  }
}
