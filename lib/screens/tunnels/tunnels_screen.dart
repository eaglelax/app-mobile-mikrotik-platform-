import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/tunnel_service.dart';
import 'tunnel_form_screen.dart';

class TunnelsScreen extends StatefulWidget {
  const TunnelsScreen({super.key});

  @override
  State<TunnelsScreen> createState() => _TunnelsScreenState();
}

class _TunnelsScreenState extends State<TunnelsScreen> {
  final _service = TunnelService();
  List<Map<String, dynamic>> _tunnels = [];
  bool _loading = true;
  String? _error;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _load(),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.fetchAll();
      if (data['success'] == false) {
        _error = data['error']?.toString() ?? 'Erreur inconnue';
        _tunnels = [];
      } else {
        final peers = data['peers'] ?? data['tunnels'];
        _tunnels = (peers is List ? peers : []).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _error = e.toString();
      _tunnels = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteTunnel(Map<String, dynamic> t) async {
    final name = t['tunnel_label'] ?? t['tunnel_name'] ?? 'ce tunnel';
    final tunnelId = t['id'] ?? t['tunnel_id'];
    if (tunnelId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le tunnel'),
        content: Text('Supprimer "$name" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _service.delete(int.parse(tunnelId.toString()));
      if (result['success'] == true) {
        _load();
      } else if (mounted) {
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
  }

  int get _activeCount =>
      _tunnels.where((t) => t['status'] == 'active').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: Builder(
        builder: (ctx) {
          final auth = ctx.read<AuthProvider>();
          final quota = auth.user?.getQuota('vpn') ?? 0;
          final canCreate = auth.isAdmin || _tunnels.length < quota;
          return FloatingActionButton(
            onPressed: () async {
              if (!canCreate) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Limite atteinte ($quota tunnels max)'),
                    backgroundColor: AppTheme.warning,
                  ),
                );
                return;
              }
              final created = await Navigator.push<bool>(
                ctx,
                MaterialPageRoute(builder: (_) => const TunnelFormScreen()),
              );
              if (created == true) _load();
            },
            backgroundColor: canCreate ? AppTheme.primary : Colors.grey,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // -- Custom Header --
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tunnels VPN',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _badge(
                    '$_activeCount actif${_activeCount > 1 ? 's' : ''}',
                    AppTheme.success,
                  ),
                  const SizedBox(width: 6),
                  _badge(
                    '${_tunnels.length} total',
                    isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: subtitleColor),
                    onPressed: _load,
                  ),
                ],
              ),
            ),

            // -- Content --
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppTheme.primary,
                      child: _error != null
                          ? _buildError(cardColor, textColor, subtitleColor, borderColor)
                          : _tunnels.isEmpty
                              ? _buildEmpty(subtitleColor)
                              : _buildList(cardColor, textColor, subtitleColor, borderColor, isDark),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Badge widget ----------
  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ---------- Error state ----------
  Widget _buildError(
      Color cardColor, Color textColor, Color subtitleColor, Color borderColor) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.warning,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de chargement',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: subtitleColor),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Empty state ----------
  Widget _buildEmpty(Color subtitleColor) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.vpn_key_off_rounded, size: 56, color: subtitleColor),
                const SizedBox(height: 12),
                Text(
                  'Aucun tunnel VPN',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Tunnel list ----------
  Widget _buildList(Color cardColor, Color textColor, Color subtitleColor,
      Color borderColor, bool isDark) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _tunnels.length,
      itemBuilder: (ctx, i) {
        final t = _tunnels[i];
        final status = t['status'] ?? 'unknown';
        final isActive = status == 'active';
        final statusColor = isActive ? AppTheme.success : Colors.grey;

        return GestureDetector(
          onLongPress: () => _deleteTunnel(t),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // -- Icon --
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // -- Info --
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['tunnel_label'] ?? t['tunnel_name'] ?? '',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (t['vpn_ip'] != null)
                        _infoRow(Icons.language, 'IP: ${t['vpn_ip']}', subtitleColor),
                      if (t['site_name'] != null)
                        _infoRow(Icons.router_outlined, t['site_name'], subtitleColor),
                      if (t['forwarded_api_port'] != null)
                        _infoRow(
                          Icons.swap_horiz,
                          'API=${t['forwarded_api_port']}  WinBox=${t['forwarded_winbox_port'] ?? '-'}',
                          subtitleColor,
                        ),
                    ],
                  ),
                ),

                // -- Status badge --
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Actif' : status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
