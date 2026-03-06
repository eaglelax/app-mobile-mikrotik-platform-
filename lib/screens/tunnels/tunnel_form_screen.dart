import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/tunnel_service.dart';
import '../../widgets/site_selector.dart';
import '../../models/site.dart';

class TunnelFormScreen extends StatefulWidget {
  const TunnelFormScreen({super.key});

  @override
  State<TunnelFormScreen> createState() => _TunnelFormScreenState();
}

class _TunnelFormScreenState extends State<TunnelFormScreen> {
  final _service = TunnelService();
  Site? _site;
  bool _submitting = false;

  Future<void> _create() async {
    if (_site == null) return;
    setState(() => _submitting = true);
    try {
      final result = await _service.create({
        'site_id': _site!.id,
      });
      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Tunnel créé avec succès'),
                backgroundColor: AppTheme.success),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['error'] ?? 'Erreur'),
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
      appBar: AppBar(title: const Text('Nouveau tunnel VPN')),
      body: _site == null
          ? SiteSelector(
              title: 'Sélectionnez le site pour le tunnel',
              onSelect: (s) => setState(() => _site = s),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.vpn_lock,
                              size: 48, color: AppTheme.primary),
                          const SizedBox(height: 12),
                          Text(_site!.nom,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(_site!.routerIp,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 14)),
                          const SizedBox(height: 16),
                          const Text(
                            'Un tunnel WireGuard sera créé entre le serveur VPS et le routeur MikroTik de ce site.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _create,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add),
                      label: Text(
                          _submitting ? 'Création...' : 'Créer le tunnel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(() => _site = null),
                    child: const Text('Changer de site'),
                  ),
                ],
              ),
            ),
    );
  }
}
