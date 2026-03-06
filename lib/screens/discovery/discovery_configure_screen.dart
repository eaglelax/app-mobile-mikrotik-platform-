import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class DiscoveryConfigureScreen extends StatefulWidget {
  final Map<String, dynamic> routerInfo;
  const DiscoveryConfigureScreen({super.key, required this.routerInfo});

  @override
  State<DiscoveryConfigureScreen> createState() =>
      _DiscoveryConfigureScreenState();
}

class _DiscoveryConfigureScreenState extends State<DiscoveryConfigureScreen> {
  final _api = ApiClient();
  bool _loading = true;
  Map<String, dynamic>? _diagnostic;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    setState(() => _loading = true);
    try {
      final result = await _api.post('/api/diagnostic.php', {
        'router_ip': widget.routerInfo['router_ip'],
        'router_user': widget.routerInfo['router_user'],
        'router_password': widget.routerInfo['router_password'],
        'router_port': widget.routerInfo['router_port'],
      });
      _diagnostic = result;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic routeur'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _runDiagnostic),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _diagnostic == null
              ? const Center(child: Text('Erreur de diagnostic'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Status card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              _diagnostic!['success'] == true
                                  ? Icons.check_circle
                                  : Icons.error,
                              size: 48,
                              color: _diagnostic!['success'] == true
                                  ? AppTheme.success
                                  : AppTheme.danger,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _diagnostic!['success'] == true
                                  ? 'Routeur accessible'
                                  : 'Routeur inaccessible',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            if (_diagnostic!['error'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _diagnostic!['error'].toString(),
                                  style: const TextStyle(
                                      color: AppTheme.danger, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Details
                    if (_diagnostic!['data'] != null) ...[
                      const Text('Informations',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      ...(_diagnostic!['data'] as Map<String, dynamic>)
                          .entries
                          .map((e) => Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                child: ListTile(
                                  title: Text(e.key,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600)),
                                  trailing: Text(e.value.toString(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  dense: true,
                                ),
                              )),
                    ],

                    // Connection info
                    const SizedBox(height: 16),
                    const Text('Paramètres de connexion',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _InfoRow('IP',
                                widget.routerInfo['router_ip'] ?? ''),
                            _InfoRow('Port',
                                '${widget.routerInfo['router_port'] ?? 8728}'),
                            _InfoRow('Utilisateur',
                                widget.routerInfo['router_user'] ?? ''),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
