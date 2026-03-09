import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class AutomatisationScreen extends StatefulWidget {
  const AutomatisationScreen({super.key});

  @override
  State<AutomatisationScreen> createState() => _AutomatisationScreenState();
}

class _AutomatisationScreenState extends State<AutomatisationScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _configs = [];
  bool _loading = true;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.get('/api/auto-generate-config.php');
      final d = data['data'] ?? data;
      _configs = (d['configs'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editConfig(Map<String, dynamic> config) async {
    final coverageCtrl = TextEditingController(
        text: (config['min_coverage_days'] ?? '').toString());
    final restockCtrl = TextEditingController(
        text: (config['restock_days'] ?? '').toString());
    final maxCtrl = TextEditingController(
        text: (config['max_generate'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier la règle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${config['site_name']} - ${config['profile_name']}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              TextField(
                controller: coverageCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Couverture min (jours)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: restockCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Restock (jours)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Max génération'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    try {
      await _api.post('/api/auto-generate-config.php', {
        'action': 'update_config',
        'config_id': config['id'],
        'min_coverage_days': int.tryParse(coverageCtrl.text) ?? 3,
        'restock_days': int.tryParse(restockCtrl.text) ?? 3,
        'max_generate': int.tryParse(maxCtrl.text) ?? 50,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _deleteConfig(Map<String, dynamic> config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette règle ?'),
        content: Text(
            '${config['site_name']} - ${config['profile_name']} sera supprimé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/api/auto-generate-config.php', {
        'action': 'delete_config',
        'config_id': config['id'],
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _toggleConfig(Map<String, dynamic> config, bool value) async {
    final id = config['id'];
    if (id == null) return;
    setState(() => config['enabled'] = value ? 1 : 0);
    try {
      await _api.post('/api/auto-generate-config.php', {
        'action': 'update_config',
        'config_id': id,
        'enabled': value,
      });
    } catch (e) {
      if (mounted) {
        setState(() => config['enabled'] = value ? 0 : 1);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la mise à jour')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // -- Custom header --
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Automatisation',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_loading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_configs.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: subtitleColor),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            // -- Body --
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _configs.isEmpty
                      ? _buildEmptyState(textColor, subtitleColor)
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _configs.length,
                            itemBuilder: (ctx, i) => _buildConfigCard(
                              _configs[i],
                              cardColor: cardColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              borderColor: borderColor,
                              isDark: isDark,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_mode_rounded,
                size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Aucune configuration',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Configurez la génération\nautomatique de tickets',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: subtitleColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigCard(
    Map<String, dynamic> c, {
    required Color cardColor,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required bool isDark,
  }) {
    final enabled = c['enabled'] == true || c['enabled'] == 1;
    final siteName = c['site_name'] ?? '';
    final profileName = c['profile_name'] ?? '';
    final coverage = c['min_coverage_days'] ?? '-';
    final restock = c['restock_days'] ?? '-';
    final max = c['max_generate'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // -- Icon with colored background --
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled
                    ? AppTheme.success.withValues(alpha: 0.12)
                    : Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.auto_mode_rounded,
                size: 22,
                color: enabled ? AppTheme.success : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),

            // -- Title + subtitle --
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$siteName - $profileName',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Couverture: ${coverage}j  |  '
                    'Restock: ${restock}j  |  '
                    'Max: $max',
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // -- Switch --
            Switch(
              value: enabled,
              onChanged: (v) => _toggleConfig(c, v),
              activeThumbColor: AppTheme.success,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),

            // -- Popup menu --
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: subtitleColor, size: 20),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                      SizedBox(width: 8),
                      Text('Supprimer',
                          style: TextStyle(color: AppTheme.danger)),
                    ],
                  ),
                ),
              ],
              onSelected: (action) {
                if (action == 'edit') {
                  _editConfig(c);
                } else if (action == 'delete') {
                  _deleteConfig(c);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
