import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../widgets/site_selector.dart';

class ProfilesListScreen extends StatefulWidget {
  final Site? site;
  const ProfilesListScreen({super.key, this.site});

  @override
  State<ProfilesListScreen> createState() => _ProfilesListScreenState();
}

class _ProfilesListScreenState extends State<ProfilesListScreen> {
  final _service = MikhmonService();
  Site? _site;
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site != null) _load();
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() => _loading = true);
    try {
      final data = await _service.fetchProfiles(_site!.id);
      _profiles = (data['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profils')),
        body: SiteSelector(onSelect: (s) {
          setState(() => _site = s);
          _load();
        }),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profils'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(child: Text('Aucun profil'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _profiles.length,
                  itemBuilder: (ctx, i) {
                    final p = _profiles[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.wifi, color: AppTheme.primary),
                        title: Text(p['name'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Débit: ${p['rate-limit'] ?? p['rate_limit'] ?? '-'}\n'
                            'Durée: ${p['limit_uptime'] ?? p['limit-uptime'] ?? '-'}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: p['ticket_price'] != null
                            ? Text('${p['ticket_price']} ${p['currency'] ?? 'FCFA'}',
                                style: const TextStyle(
                                    color: AppTheme.success,
                                    fontWeight: FontWeight.w700))
                            : null,
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
