import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/api_client.dart';
import '../../widgets/site_selector.dart';

class ScriptsScreen extends StatefulWidget {
  const ScriptsScreen({super.key});

  @override
  State<ScriptsScreen> createState() => _ScriptsScreenState();
}

class _ScriptsScreenState extends State<ScriptsScreen> {
  final _api = ApiClient();
  Site? _site;
  bool _deploying = false;

  Future<void> _deploy() async {
    if (_site == null) return;
    setState(() => _deploying = true);
    try {
      final result =
          await _api.post('/api/deploy.php', {'site_id': _site!.id});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Déploiement lancé'),
            backgroundColor:
                result['success'] == true ? AppTheme.success : AppTheme.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    if (mounted) setState(() => _deploying = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scripts & Déploiement')),
        body: SiteSelector(
          title: 'Sélectionnez un site pour déployer',
          onSelect: (s) => setState(() => _site = s),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _site = null);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Scripts & Déploiement'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.swap_horiz),
              onPressed: () => setState(() => _site = null)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        size: 48, color: AppTheme.primary),
                    const SizedBox(height: 12),
                    const Text('Déployer la configuration',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Envoyer la configuration actuelle au routeur MikroTik de ${_site!.nom}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _deploying ? null : _deploy,
                icon: _deploying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.rocket_launch),
                label:
                    Text(_deploying ? 'Déploiement...' : 'Lancer le déploiement'),
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
