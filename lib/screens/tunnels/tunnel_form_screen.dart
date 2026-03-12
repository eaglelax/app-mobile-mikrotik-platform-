import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/tunnel_service.dart';

class TunnelFormScreen extends StatefulWidget {
  const TunnelFormScreen({super.key});

  @override
  State<TunnelFormScreen> createState() => _TunnelFormScreenState();
}

class _TunnelFormScreenState extends State<TunnelFormScreen> {
  final _service = TunnelService();
  final _labelCtrl = TextEditingController();
  bool _submitting = false;

  Future<void> _create() async {
    setState(() => _submitting = true);
    try {
      final data = <String, dynamic>{'action': 'create'};
      final label = _labelCtrl.text.trim();
      if (label.isNotEmpty) data['label'] = label;

      final result = await _service.create(data);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tunnel cree avec succes'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur'), backgroundColor: AppTheme.danger),
        );
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
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon + description
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                      child: Column(
                        children: [
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.vpn_lock, size: 32, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 16),
                          Text('Creer un tunnel VPN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 8),
                          Text(
                            'Un tunnel WireGuard sera cree sur le serveur VPS. Vous pourrez ensuite l\'associer a un site.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Label field
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nom du tunnel (optionnel)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _labelCtrl,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Ex: Mon site WiFi',
                              hintStyle: TextStyle(color: subtitleColor),
                              filled: true,
                              fillColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Create button
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
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 10),
                                  Text('Creation...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add, size: 20),
                                  SizedBox(width: 8),
                                  Text('Creer le tunnel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
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
