import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class IpBindingsScreen extends StatefulWidget {
  final Site site;
  const IpBindingsScreen({super.key, required this.site});

  @override
  State<IpBindingsScreen> createState() => _IpBindingsScreenState();
}

class _IpBindingsScreenState extends State<IpBindingsScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _bindings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchIpBindings(widget.site.id);
      _bindings =
          (data['bindings'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('IP Bindings (${_bindings.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bindings.isEmpty
              ? const Center(child: Text('Aucun binding'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bindings.length,
                    itemBuilder: (ctx, i) {
                      final b = _bindings[i];
                      final type = b['type'] ?? 'regular';
                      final typeColor = type == 'bypassed'
                          ? AppTheme.success
                          : type == 'blocked'
                              ? AppTheme.danger
                              : AppTheme.primary;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Icon(
                            type == 'blocked'
                                ? Icons.block
                                : type == 'bypassed'
                                    ? Icons.check_circle_outline
                                    : Icons.lan_outlined,
                            color: typeColor,
                          ),
                          title: Text(
                            b['address'] ?? b['mac-address'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                fontSize: 14),
                          ),
                          subtitle: Text(
                            'MAC: ${b['mac-address'] ?? '-'}\n'
                            'Serveur: ${b['server'] ?? '-'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(type,
                                style: TextStyle(
                                    color: typeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
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
