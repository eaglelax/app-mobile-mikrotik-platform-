import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';
import 'discovery_configure_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _api = ApiClient();
  final _ipCtrl = TextEditingController();
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8728');
  bool _scanning = false;
  Map<String, dynamic>? _result;

  Future<void> _scan() async {
    if (_ipCtrl.text.isEmpty) return;
    setState(() {
      _scanning = true;
      _result = null;
    });

    try {
      _result = await _api.post('/api/router-test.php', {
        'router_ip': _ipCtrl.text.trim(),
        'router_user': _userCtrl.text.trim(),
        'router_password': _passCtrl.text,
        'router_port': int.tryParse(_portCtrl.text) ?? 8728,
      });
    } catch (e) {
      _result = {'success': false, 'error': e.toString()};
    }

    if (mounted) setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Découverte Routeur')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Testez la connexion à un routeur MikroTik',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ipCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse IP du routeur',
                prefixIcon: Icon(Icons.router),
                hintText: '192.168.1.1',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(labelText: 'Utilisateur'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _portCtrl,
                    decoration: const InputDecoration(labelText: 'Port API'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outlined),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _scanning ? null : _scan,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_scanning ? 'Test en cours...' : 'Tester la connexion'),
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              Card(
                color: _result!['success'] == true
                    ? AppTheme.success.withValues(alpha: 0.1)
                    : AppTheme.danger.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        _result!['success'] == true
                            ? Icons.check_circle
                            : Icons.error,
                        color: _result!['success'] == true
                            ? AppTheme.success
                            : AppTheme.danger,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _result!['success'] == true
                            ? 'Connexion réussie !'
                            : 'Échec de connexion',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      if (_result!['error'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_result!['error'],
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey)),
                        ),
                      if ((_result!['router_version'] ?? _result!['version']) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                              'RouterOS: ${_result!['router_version'] ?? _result!['version']}',
                              style: const TextStyle(fontSize: 13)),
                        ),
                      if (_result!['response_time'] != null)
                        Text('Temps de réponse: ${_result!['response_time']}ms',
                            style: const TextStyle(fontSize: 13)),
                      if (_result!['success'] == true) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DiscoveryConfigureScreen(
                                routerInfo: {
                                  'router_ip': _ipCtrl.text.trim(),
                                  'router_user': _userCtrl.text.trim(),
                                  'router_password': _passCtrl.text,
                                  'router_port': int.tryParse(_portCtrl.text) ?? 8728,
                                  ..._result!,
                                },
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.settings),
                          label: const Text('Diagnostiquer'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }
}
