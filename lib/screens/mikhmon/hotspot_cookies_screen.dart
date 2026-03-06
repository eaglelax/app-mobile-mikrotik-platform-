import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class HotspotCookiesScreen extends StatefulWidget {
  final Site site;
  const HotspotCookiesScreen({super.key, required this.site});

  @override
  State<HotspotCookiesScreen> createState() => _HotspotCookiesScreenState();
}

class _HotspotCookiesScreenState extends State<HotspotCookiesScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _cookies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchCookies(widget.site.id);
      _cookies = (data['cookies'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _remove(Map<String, dynamic> cookie) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce cookie ?'),
        content: Text('Cookie de "${cookie['user'] ?? ''}" sera supprimé.'),
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
      await _service.removeCookie(widget.site.id, cookie['.id'] ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Cookie supprimé'),
              backgroundColor: AppTheme.success),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cookies Hotspot (${_cookies.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cookies.isEmpty
              ? const Center(child: Text('Aucun cookie'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _cookies.length,
                    itemBuilder: (ctx, i) {
                      final c = _cookies[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: const Icon(Icons.cookie_outlined,
                              color: AppTheme.accent),
                          title: Text(c['user'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            'MAC: ${c['mac-address'] ?? '-'}\n'
                            'Expire: ${c['expires-in'] ?? '-'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.danger, size: 20),
                            onPressed: () => _remove(c),
                          ),
                          isThreeLine: true,
                          dense: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
