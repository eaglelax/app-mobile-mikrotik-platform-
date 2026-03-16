import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/auth_provider.dart';
import '../../services/site_service.dart';
import '../../services/mikhmon_service.dart';
import '../../services/tunnel_service.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';
import '../mikhmon/hotspot_users_screen.dart';
import '../mikhmon/hotspot_active_screen.dart';
import '../mikhmon/flash_sale_screen.dart';
import '../mikhmon/quick_print_screen.dart';
import '../mikhmon/traffic_screen.dart';
import '../mikhmon/hotspot_servers_screen.dart';
import '../mikhmon/dhcp_leases_screen.dart';
import '../points/points_list_screen.dart';
import '../mikhmon/system_controls_screen.dart';
import '../mikhmon/logs_screen.dart';
import '../mikhmon/hotspot_cookies_screen.dart';
import '../mikhmon/ip_bindings_screen.dart';
import '../mikhmon/mikhmon_report_screen.dart';
import '../reports/site_report_screen.dart';
import '../tickets/ticket_batches_screen.dart';

class SiteDetailScreen extends StatefulWidget {
  final Site site;
  const SiteDetailScreen({super.key, required this.site});

  @override
  State<SiteDetailScreen> createState() => _SiteDetailScreenState();
}

class _SiteDetailScreenState extends State<SiteDetailScreen> {
  final _siteService = SiteService();
  final _mikhmonService = MikhmonService();
  final _tunnelService = TunnelService();
  final _api = ApiClient();
  Map<String, dynamic>? _stats;
  bool _loading = true;

  // Tunnel deploy
  Map<String, dynamic>? _siteTunnel;
  Map<String, dynamic>? _deployInfo;
  bool _loadingToken = false;
  Timer? _countdownTimer;
  int _tokenSecondsLeft = 0;

  // Gateway access (temporary secure links)
  Map<String, dynamic>? _mikhmonAccess;
  Map<String, dynamic>? _winboxAccess;
  bool _loadingMikhmon = false;
  bool _loadingWinbox = false;
  Timer? _mikhmonTimer;
  Timer? _winboxTimer;
  int _mikhmonTtl = 0;
  int _winboxTtl = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadTunnel()]);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _mikhmonTimer?.cancel();
    _winboxTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTunnel() async {
    try {
      final data = await _tunnelService.fetchAll();
      final tunnels = (data['tunnels'] ?? data['peers'] ?? []) as List;
      for (final t in tunnels) {
        if (t['site_id']?.toString() == widget.site.id.toString()) {
          if (mounted) setState(() => _siteTunnel = Map<String, dynamic>.from(t));
          break;
        }
      }
    } catch (_) {}
  }

  Future<void> _generateToken() async {
    final tunnelId = _siteTunnel?['id'];
    if (tunnelId == null) return;
    setState(() => _loadingToken = true);
    try {
      final result = await _tunnelService.deployToken(int.parse(tunnelId.toString()));
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
      }
    } catch (_) {
      if (mounted) setState(() => _loadingToken = false);
    }
  }

  Future<void> _requestGateway(String action) async {
    final slug = _siteTunnel?['slug']?.toString();
    if (slug == null || slug.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slug du tunnel introuvable'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    final isMikhmon = action == 'mikhmon';
    setState(() {
      if (isMikhmon) {
        _loadingMikhmon = true;
      } else {
        _loadingWinbox = true;
      }
    });

    try {
      final result = await _tunnelService.gatewayAccess(slug, action);
      if (!mounted) return;
      if (result['success'] == true) {
        final ttl = result['ttl'] ?? 300;
        if (isMikhmon) {
          _mikhmonTimer?.cancel();
          setState(() {
            _mikhmonAccess = result;
            _mikhmonTtl = ttl;
            _loadingMikhmon = false;
          });
          _mikhmonTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (_mikhmonTtl <= 0) {
              _mikhmonTimer?.cancel();
              if (mounted) setState(() => _mikhmonAccess = null);
            } else {
              if (mounted) setState(() => _mikhmonTtl--);
            }
          });
        } else {
          _winboxTimer?.cancel();
          setState(() {
            _winboxAccess = result;
            _winboxTtl = ttl;
            _loadingWinbox = false;
          });
          _winboxTimer = Timer.periodic(const Duration(seconds: 1), (_) {
            if (_winboxTtl <= 0) {
              _winboxTimer?.cancel();
              if (mounted) setState(() => _winboxAccess = null);
            } else {
              if (mounted) setState(() => _winboxTtl--);
            }
          });
        }
      } else {
        setState(() {
          if (isMikhmon) {
            _loadingMikhmon = false;
          } else {
            _loadingWinbox = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (isMikhmon) {
            _loadingMikhmon = false;
          } else {
            _loadingWinbox = false;
          }
        });
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

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      // Parallel fetch: site stats + mikhmon dashboard
      final results = await Future.wait([
        _siteService.fetchStats(widget.site.id),
        _mikhmonService.fetchDashboard(widget.site.id).catchError((_) => <String, dynamic>{}),
      ]);

      final raw = results[0];
      final data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
      final mikhmonData = results[1];
      final activeUsers = mikhmonData['active']?['count'] ?? 0;

      _stats = {
        'today_revenue': data['revenue'] ?? 0,
        'today_sales': data['sold'] ?? 0,
        'unsold_vouchers': data['available'] ?? 0,
        'active_users': activeUsers,
      };
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteSite() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer ce site ?'),
        content: Text(
            'Le site "${widget.site.nom}" et toutes ses données seront supprimés. Cette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.post('/api/full-setup.php', {
        'action': 'delete',
        'site_id': widget.site.id,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site supprime'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _confirmReboot() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redémarrer le routeur ?'),
        content: Text(
            'Le routeur ${widget.site.nom} sera redémarré. Les utilisateurs actifs seront déconnectés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Redémarrer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _mikhmonService.rebootRouter(widget.site.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redémarrage lancé')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final shadow = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

    final auth = context.read<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final tunnelIsActive = _siteTunnel?['status'] == 'active';
    final hasSlug = (_siteTunnel?['slug']?.toString() ?? '').isNotEmpty;

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(site.nom, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                        Text(site.routerIp, style: TextStyle(fontSize: 13, color: subtitleColor)),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(Icons.refresh_rounded, color: textColor), onPressed: _loadStats),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadStats,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Revenue Hero Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text("Revenu aujourd'hui", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.8))),
                                const SizedBox(height: 8),
                                Text(
                                  Fmt.currency(_stats?['today_revenue'] ?? 0),
                                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _miniStat('${_stats?['active_users'] ?? 0}', 'Actifs', Icons.person),
                                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                                    _miniStat('${_stats?['unsold_vouchers'] ?? 0}', 'Stock', Icons.inventory_2_outlined),
                                    Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                                    _miniStat('${_stats?['today_sales'] ?? 0}', 'Ventes', Icons.receipt_long),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Quick Actions
                          Text('Actions rapides', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _quickActionTile(Icons.bolt, 'Flash', AppTheme.accent, () => _push(FlashSaleScreen(site: site)), isDark, cardColor, textColor, shadow)),
                              const SizedBox(width: 8),
                              Expanded(child: _quickActionTile(Icons.print, 'Print', AppTheme.primary, () => _push(QuickPrintScreen(site: site)), isDark, cardColor, textColor, shadow)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _quickActionTile(
                                  Icons.storefront,
                                  'Points',
                                  AppTheme.success,
                                  () => _push(PointsListScreen(site: site)),
                                  isDark, cardColor, textColor, shadow,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: _quickActionTile(Icons.inventory_2_outlined, 'Tickets', AppTheme.info, () => _push(TicketBatchesScreen(site: site)), isDark, cardColor, textColor, shadow)),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Hotspot
                          Text('Hotspot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _menuItem(Icons.people_outline, 'Utilisateurs', () => _push(HotspotUsersScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.wifi_tethering, 'Connexions Actives', () => _push(HotspotActiveScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.dns_outlined, 'Serveurs', () => _push(HotspotServersScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.cable_outlined, 'DHCP Leases', () => _push(DhcpLeasesScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.bar_chart_rounded, 'Trafic', () => _push(TrafficScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.cookie_outlined, 'Cookies', () => _push(HotspotCookiesScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.lan_outlined, 'IP Bindings', () => _push(IpBindingsScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.article_outlined, 'Logs', () => _push(LogsScreen(site: site)), textColor, subtitleColor, dividerColor, isLast: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Rapports
                          Text('Rapports', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _menuItem(Icons.assessment_outlined, 'Rapport Mikhmon', () => _push(MikhmonReportScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.analytics_outlined, 'Rapport du Site', () => _push(SiteReportScreen(site: site)), textColor, subtitleColor, dividerColor, isLast: true),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Systeme
                          Text('Systeme', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                          const SizedBox(height: 10),
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                _menuItem(Icons.settings_outlined, 'Controles Systeme', () => _push(SystemControlsScreen(site: site)), textColor, subtitleColor, dividerColor),
                                _menuItem(Icons.restart_alt, 'Redemarrer le Routeur', () => _confirmReboot(), textColor, subtitleColor, dividerColor, isLast: true, isDanger: true),
                              ],
                            ),
                          ),

                          // Tunnel VPN section
                          if (_siteTunnel != null) ...[
                            const SizedBox(height: 20),
                            Text('Tunnel VPN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tunnel header
                                  Row(
                                    children: [
                                      const Icon(Icons.vpn_lock, size: 18, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(_siteTunnel!['tunnel_label'] ?? _siteTunnel!['tunnel_name'] ?? '', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (tunnelIsActive ? AppTheme.success : Colors.orange).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          tunnelIsActive ? 'Actif' : (_siteTunnel!['status'] ?? ''),
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tunnelIsActive ? AppTheme.success : Colors.orange),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text('IP VPN: ${_siteTunnel!['vpn_ip'] ?? '-'}', style: TextStyle(fontSize: 12, color: subtitleColor)),

                                  // Secure access links (for all users)
                                  if (tunnelIsActive && hasSlug) ...[
                                    const SizedBox(height: 16),
                                    Text('Acces securise', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                                    const SizedBox(height: 10),

                                    // Mikhmon
                                    _gatewayAccessTile(
                                      icon: Icons.web,
                                      label: 'Mikhmon',
                                      color: AppTheme.primary,
                                      isLoading: _loadingMikhmon,
                                      accessData: _mikhmonAccess,
                                      ttl: _mikhmonTtl,
                                      onRequest: () => _requestGateway('mikhmon'),
                                      textColor: textColor,
                                      subtitleColor: subtitleColor,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 8),

                                    // Winbox
                                    _gatewayAccessTile(
                                      icon: Icons.settings_remote,
                                      label: 'WinBox',
                                      color: Colors.orange,
                                      isLoading: _loadingWinbox,
                                      accessData: _winboxAccess,
                                      ttl: _winboxTtl,
                                      onRequest: () => _requestGateway('winbox'),
                                      textColor: textColor,
                                      subtitleColor: subtitleColor,
                                      isDark: isDark,
                                    ),
                                  ],

                                  // Deploy command (admin only)
                                  if (isAdmin) ...[
                                    const SizedBox(height: 16),
                                    Divider(color: dividerColor),
                                    const SizedBox(height: 10),
                                    Text('Commande API', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                                    const SizedBox(height: 10),
                                    if (_deployInfo == null)
                                      SizedBox(
                                        width: double.infinity, height: 44,
                                        child: ElevatedButton.icon(
                                          onPressed: _loadingToken ? null : _generateToken,
                                          icon: _loadingToken
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                              : const Icon(Icons.terminal, size: 16),
                                          label: Text(_loadingToken ? 'Generation...' : 'Generer commande API'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      )
                                    else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: (_tokenSecondsLeft > 60 ? AppTheme.success : Colors.orange).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.timer, size: 16, color: _tokenSecondsLeft > 60 ? AppTheme.success : Colors.orange),
                                            const SizedBox(width: 6),
                                            Text('Expire dans ${_fmtCountdown(_tokenSecondsLeft)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _tokenSecondsLeft > 60 ? AppTheme.success : Colors.orange)),
                                            const Spacer(),
                                            GestureDetector(onTap: _generateToken, child: Icon(Icons.refresh, size: 16, color: subtitleColor)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1A1D21) : const Color(0xFFF0F2F5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SelectableText(
                                              _deployInfo!['fetch_command'] ?? '',
                                              style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: isDark ? Colors.green.shade300 : Colors.green.shade800),
                                            ),
                                            const SizedBox(height: 6),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: GestureDetector(
                                                onTap: () => _copy(_deployInfo!['fetch_command'] ?? '', 'Commande'),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.copy, size: 12, color: AppTheme.primary),
                                                      SizedBox(width: 4),
                                                      Text('Copier', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Delete (admin only)
                          if (isAdmin)
                            GestureDetector(
                              onTap: _deleteSite,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_outline, color: AppTheme.danger, size: 18),
                                    SizedBox(width: 8),
                                    Text('Supprimer ce site', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gatewayAccessTile({
    required IconData icon,
    required String label,
    required Color color,
    required bool isLoading,
    required Map<String, dynamic>? accessData,
    required int ttl,
    required VoidCallback onRequest,
    required Color textColor,
    required Color subtitleColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor))),
              if (accessData == null)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Ouvrir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          if (accessData != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final addr = '${accessData['host']}:${accessData['port']}';
                _copy(addr, label);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${accessData['host']}:${accessData['port']}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', color: color),
                      ),
                    ),
                    Icon(Icons.copy, size: 14, color: color),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 12, color: ttl > 60 ? AppTheme.success : Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Expire dans ${_fmtCountdown(ttl)}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ttl > 60 ? AppTheme.success : Colors.orange),
                ),
                const Spacer(),
                if (accessData['client_ip'] != null)
                  Text('IP: ${accessData['client_ip']}', style: TextStyle(fontSize: 10, color: subtitleColor)),
                const SizedBox(width: 6),
                GestureDetector(onTap: onRequest, child: Icon(Icons.refresh, size: 14, color: subtitleColor)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _quickActionTile(IconData icon, String label, Color color, VoidCallback onTap, bool isDark, Color cardColor, Color textColor, List<BoxShadow> shadow) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: shadow,
        ),
        child: Column(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap, Color textColor, Color subtitleColor, Color dividerColor, {bool isLast = false, bool isDanger = false}) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: isDanger ? AppTheme.danger : subtitleColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: isDanger ? AppTheme.danger : textColor)),
                ),
                Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (!isLast) Padding(
          padding: const EdgeInsets.only(left: 50),
          child: Divider(height: 1, color: dividerColor),
        ),
      ],
    );
  }
}
