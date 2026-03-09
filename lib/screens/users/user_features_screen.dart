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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Permissions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                        Text(widget.user['name'] ?? '', style: TextStyle(fontSize: 13, color: subtitleColor)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _saving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sauver', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Fonctionnalités
                        Text('Fonctionnalités', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: shadow,
                          ),
                          child: Column(
                            children: [
                              _buildFeatureSwitch('Mikhmon', 'feature_mikhmon', Icons.router, isDark, cardColor),
                              Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                              _buildFeatureSwitch('Statistiques', 'feature_statistics', Icons.bar_chart, isDark, cardColor),
                              Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                              _buildFeatureSwitch('VPN', 'feature_vpn', Icons.vpn_key, isDark, cardColor),
                              Divider(height: 1, indent: 56, color: Colors.grey.shade200),
                              _buildFeatureSwitch('Auto-génération', 'feature_autogenerate', Icons.autorenew, isDark, cardColor),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Quotas
                        Text('Quotas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: shadow,
                          ),
                          child: Column(
                            children: [
                              _buildQuotaField('Max Sites', 'max_sites', Icons.language, isDark),
                              const SizedBox(height: 12),
                              _buildQuotaField('Max VPN', 'max_vpn', Icons.vpn_key, isDark),
                              const SizedBox(height: 12),
                              _buildQuotaField('Max Auto-gen Configs', 'max_autogen_configs', Icons.settings, isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureSwitch(String label, String key, IconData icon, bool isDark, Color cardColor) {
    final isOn = _features[key] == true || _features[key] == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isOn ? AppTheme.success.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: isOn ? AppTheme.success : Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF1A1D21),
            )),
          ),
          Switch.adaptive(
            value: isOn,
            onChanged: (v) => setState(() => _features[key] = v),
            activeTrackColor: AppTheme.success,
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaField(String label, String key, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            initialValue: '${_features[key] ?? 0}',
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              filled: true,
              fillColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _features[key] = int.tryParse(v) ?? 0,
          ),
        ),
      ],
    );
  }
}
