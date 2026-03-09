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
                  Text('Nouveau tunnel VPN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _site == null
                  ? SiteSelector(
                      title: 'Sélectionnez le site pour le tunnel',
                      onSelect: (s) => setState(() => _site = s),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: shadow,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.vpn_lock, size: 32, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(_site!.nom, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                                const SizedBox(height: 4),
                                Text(_site!.routerIp, style: TextStyle(color: subtitleColor, fontSize: 14)),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    'Un tunnel WireGuard sera créé entre le serveur VPS et le routeur MikroTik de ce site.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: subtitleColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : _create,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _submitting
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                        const SizedBox(width: 10),
                                        const Text('Création...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      ],
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add, size: 20),
                                        SizedBox(width: 8),
                                        Text('Créer le tunnel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => setState(() => _site = null),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textColor,
                                side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Changer de site'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
