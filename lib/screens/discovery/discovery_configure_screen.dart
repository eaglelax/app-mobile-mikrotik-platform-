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
                  Expanded(
                    child: Text('Diagnostic routeur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: textColor),
                    onPressed: _runDiagnostic,
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _diagnostic == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text('Erreur de diagnostic', style: TextStyle(color: subtitleColor, fontSize: 15)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _runDiagnostic,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Status card
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
                                        color: (_diagnostic!['success'] == true ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        _diagnostic!['success'] == true ? Icons.check_circle : Icons.error,
                                        size: 32,
                                        color: _diagnostic!['success'] == true ? AppTheme.success : AppTheme.danger,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _diagnostic!['success'] == true ? 'Routeur accessible' : 'Routeur inaccessible',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
                                    ),
                                    if (_diagnostic!['error'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          _diagnostic!['error'].toString(),
                                          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Details
                              if ((_diagnostic!['results'] ?? _diagnostic!['data']) != null) ...[
                                Text('Informations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: shadow,
                                  ),
                                  child: Column(
                                    children: ((_diagnostic!['results'] ?? _diagnostic!['data']) as Map<String, dynamic>)
                                        .entries
                                        .map((e) => _InfoRow(e.key, e.value.toString(), subtitleColor, textColor))
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Connection info
                              Text('Paramètres de connexion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: shadow,
                                ),
                                child: Column(
                                  children: [
                                    _InfoRow('IP', widget.routerInfo['router_ip'] ?? '', subtitleColor, textColor),
                                    _InfoRow('Port', '${widget.routerInfo['router_port'] ?? 8728}', subtitleColor, textColor),
                                    _InfoRow('Utilisateur', widget.routerInfo['router_user'] ?? '', subtitleColor, textColor),
                                  ],
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  const _InfoRow(this.label, this.value, this.labelColor, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: valueColor)),
        ],
      ),
    );
  }
}
