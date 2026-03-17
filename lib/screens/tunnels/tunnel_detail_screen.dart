import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../services/tunnel_service.dart';

class TunnelDetailScreen extends StatefulWidget {
  final Map<String, dynamic> tunnel;
  const TunnelDetailScreen({super.key, required this.tunnel});

  @override
  State<TunnelDetailScreen> createState() => _TunnelDetailScreenState();
}

class _TunnelDetailScreenState extends State<TunnelDetailScreen> {
  final _service = TunnelService();
  late Map<String, dynamic> _tunnel;

  // Deploy token
  Map<String, dynamic>? _deployInfo;
  bool _loadingToken = false;
  Timer? _countdownTimer;
  int _tokenSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _tunnel = Map<String, dynamic>.from(widget.tunnel);
    _refreshTunnel();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTunnel() async {
    final id = _tunnel['id'] ?? _tunnel['tunnel_id'];
    if (id == null) return;
    try {
      final result = await _service.getStatus(int.parse(id.toString()));
      if (mounted && result['tunnel'] != null) {
        setState(() => _tunnel = Map<String, dynamic>.from(result['tunnel']));
      }
    } catch (_) {}
  }

  Future<void> _generateToken({String type = 'wg-inject'}) async {
    final tunnelId = _tunnel['id'] ?? _tunnel['tunnel_id'];
    if (tunnelId == null) return;
    setState(() => _loadingToken = true);
    try {
      final result = await _service.deployToken(int.parse(tunnelId.toString()), type: type);
      if (!mounted) return;
      if (result['success'] == true) {
        _countdownTimer?.cancel();
        setState(() {
          _deployInfo = result;
          _tokenSecondsLeft = result['expires_in'] ?? 300;
          _loadingToken = false;
        });
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_tokenSecondsLeft <= 0) {
            _countdownTimer?.cancel();
            if (mounted) setState(() => _deployInfo = null);
          } else {
            if (mounted) setState(() => _tokenSecondsLeft--);
          }
        });
      } else {
        setState(() => _loadingToken = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingToken = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copie'), backgroundColor: AppTheme.success, duration: const Duration(seconds: 2)),
    );
  }

  String _fmtCountdown(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final shadow = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

    final tunnelName = _tunnel['tunnel_name'] ?? _tunnel['tunnel_label'] ?? '';
    final status = _tunnel['status'] ?? 'unknown';
    final isActive = status == 'active';
    final siteName = _tunnel['site_name'] ?? '-';

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
                    child: Text('Detail du tunnel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                  ),
                  IconButton(icon: Icon(Icons.refresh_rounded, color: subtitleColor), onPressed: _refreshTunnel),
                ],
              ),
            ),

            // Body
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshTunnel,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Status banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (isActive ? AppTheme.success : Colors.orange).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: (isActive ? AppTheme.success : Colors.orange).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isActive ? Icons.check_circle : Icons.pending,
                              color: isActive ? AppTheme.success : Colors.orange,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _tunnel['tunnel_label'] ?? tunnelName,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isActive ? 'Tunnel actif' : 'Statut: $status',
                                    style: TextStyle(fontSize: 13, color: subtitleColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tunnel info
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Informations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                            const SizedBox(height: 14),
                            _infoTile(Icons.label_outline, 'Nom', tunnelName, textColor, subtitleColor),
                            _infoTile(Icons.router, 'Site', siteName, textColor, subtitleColor),
                            _infoTile(Icons.circle, 'Statut', isActive ? 'Actif' : status, textColor, subtitleColor,
                                valueColor: isActive ? AppTheme.success : Colors.orange),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Direct permanent port links
                      if (isActive && (_tunnel['forwarded_api_port'] != null || _tunnel['forwarded_winbox_port'] != null))
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Acces direct (permanent)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                              const SizedBox(height: 4),
                              Text('Ports forwarded sans limite de temps', style: TextStyle(fontSize: 12, color: subtitleColor)),
                              const SizedBox(height: 14),
                              if (_tunnel['forwarded_api_port'] != null)
                                _directPortTile(
                                  label: 'Mikhmon',
                                  icon: Icons.web,
                                  color: AppTheme.primary,
                                  address: 'vpn1.tikadmin.com:${_tunnel['forwarded_api_port']}',
                                  targetPort: '8728',
                                  textColor: textColor,
                                  isDark: isDark,
                                ),
                              if (_tunnel['forwarded_winbox_port'] != null) ...[
                                const SizedBox(height: 8),
                                _directPortTile(
                                  label: 'Winbox',
                                  icon: Icons.settings_remote,
                                  color: Colors.orange,
                                  address: 'vpn1.tikadmin.com:${_tunnel['forwarded_winbox_port']}',
                                  targetPort: '8291',
                                  textColor: textColor,
                                  isDark: isDark,
                                ),
                              ],
                              if (_tunnel['forwarded_web_port'] != null) ...[
                                const SizedBox(height: 8),
                                _directPortTile(
                                  label: 'Web',
                                  icon: Icons.language,
                                  color: AppTheme.success,
                                  address: 'http://vpn1.tikadmin.com:${_tunnel['forwarded_web_port']}',
                                  targetPort: '80',
                                  textColor: textColor,
                                  isDark: isDark,
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (isActive && (_tunnel['forwarded_api_port'] != null || _tunnel['forwarded_winbox_port'] != null))
                        const SizedBox(height: 16),

                      // Deploy commands
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.terminal, size: 20, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Text('Commande API', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Generez un token puis executez la commande dans le terminal WinBox.',
                              style: TextStyle(fontSize: 12, color: subtitleColor),
                            ),
                            const SizedBox(height: 14),
                            if (_deployInfo == null) ...[
                              SizedBox(
                                width: double.infinity, height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _loadingToken ? null : () => _generateToken(),
                                  icon: _loadingToken
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.vpn_key, size: 18),
                                  label: Text(_loadingToken ? 'Generation...' : 'Generer le token'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ] else ...[
                              // Countdown
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (_tokenSecondsLeft > 60 ? AppTheme.success : Colors.orange).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.timer, size: 18, color: _tokenSecondsLeft > 60 ? AppTheme.success : Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Expire dans ${_fmtCountdown(_tokenSecondsLeft)}',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _tokenSecondsLeft > 60 ? AppTheme.success : Colors.orange),
                                    ),
                                    const Spacer(),
                                    GestureDetector(onTap: () => _generateToken(), child: Icon(Icons.refresh, size: 18, color: subtitleColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('Commande WireGuard :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                              const SizedBox(height: 8),
                              _commandBox(_deployInfo!['fetch_command'] ?? '', isDark ? Colors.green.shade300 : Colors.green.shade800,
                                  isDark ? const Color(0xFF1A1D21) : const Color(0xFFF0F2F5), isDark ? Colors.grey.shade800 : Colors.grey.shade300, 'Commande fetch', isDark),
                              const SizedBox(height: 14),
                              Text('Reset complet (optionnel) :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                              const SizedBox(height: 8),
                              _commandBox(_deployInfo!['reset_command'] ?? '', isDark ? Colors.red.shade300 : Colors.red.shade800,
                                  isDark ? const Color(0xFF1A1D21) : const Color(0xFFFFF5F5), isDark ? Colors.red.shade900 : Colors.red.shade200, 'Commande reset', isDark),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _directPortTile({
    required String label,
    required IconData icon,
    required Color color,
    required String address,
    required String targetPort,
    required Color textColor,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: address));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label copie: $address'), duration: const Duration(seconds: 2)),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(address, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: textColor), overflow: TextOverflow.ellipsis),
            ),
            Text('→ :$targetPort', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400)),
            const SizedBox(width: 6),
            Icon(Icons.copy, size: 13, color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _commandBox(String cmd, Color textColor, Color bgColor, Color borderColor, String label, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(cmd, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: textColor)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => _copy(cmd, label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy, size: 14, color: AppTheme.primary),
                    SizedBox(width: 4),
                    Text('Copier', style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color textColor, Color subtitleColor, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: subtitleColor),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: subtitleColor))),
          Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? textColor), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
