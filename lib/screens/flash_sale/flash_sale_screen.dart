import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/auth_provider.dart';
import '../../providers/site_provider.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';

class FlashSaleScreen extends StatefulWidget {
  const FlashSaleScreen({super.key});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  final _api = ApiClient();
  Site? _selectedSite;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _points = [];
  int? _selectedPointId;
  bool _loadingProfiles = false;
  bool _generating = false;
  Map<String, dynamic>? _result;
  String? _error;
  bool _autoLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoLoaded) {
      _autoLoaded = true;
      _tryAutoSelectSite();
    }
  }

  void _tryAutoSelectSite() {
    final auth = context.read<AuthProvider>();
    if (auth.user?.isGerant == true && auth.user!.siteId != null) {
      final sites = context.read<SiteProvider>().sites;
      final match = sites.where((s) => s.id == auth.user!.siteId).toList();
      if (match.isNotEmpty) {
        _loadProfiles(match.first);
      }
    }
  }

  Future<void> _loadProfiles(Site site) async {
    setState(() {
      _selectedSite = site;
      _loadingProfiles = true;
      _profiles = [];
      _result = null;
      _error = null;
    });
    try {
      final data = await _api.get(
          ApiConfig.flashSale, {'site_id': site.id.toString()});
      if (data['success'] == true) {
        final list = data['profiles'] as List? ?? [];
        final pts = data['points'] as List? ?? [];
        setState(() {
          _profiles = list.map((p) => Map<String, dynamic>.from(p)).toList();
          _points = pts.map((p) => Map<String, dynamic>.from(p)).toList();
          // Auto-select gerant's point if applicable
          final auth = context.read<AuthProvider>();
          final gerantPointId = auth.user?.pointId;
          if (gerantPointId != null && _points.any((p) {
            final id = p['id'] is int ? p['id'] : int.tryParse(p['id'].toString());
            return id == gerantPointId;
          })) {
            _selectedPointId = gerantPointId;
          } else {
            _selectedPointId = _points.isNotEmpty
                ? (_points.first['id'] is int
                    ? _points.first['id']
                    : int.tryParse(_points.first['id'].toString()))
                : null;
          }
        });
      } else {
        setState(() => _error = data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loadingProfiles = false);
  }

  Future<void> _generate(String profileName) async {
    if (_selectedSite == null || _generating) return;
    setState(() {
      _generating = true;
      _result = null;
      _error = null;
    });
    try {
      final data = await _api.post(ApiConfig.flashSale, {
        'site_id': _selectedSite!.id,
        'profile': profileName,
        if (_selectedPointId != null) 'point_id': _selectedPointId,
      });
      if (data['success'] == true) {
        setState(() => _result = data);
      } else {
        setState(() => _error = data['error'] ?? 'Erreur generation');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sites = context.watch<SiteProvider>().sites;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return PopScope(
      canPop: _selectedSite == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() {
            _selectedSite = null;
            _profiles = [];
            _result = null;
            _error = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: _selectedSite == null
              ? _buildSiteSelector(
                  sites, isDark, cardColor, textColor, subtextColor)
              : _loadingProfiles
                  ? _buildLoadingState(isDark, textColor, subtextColor)
                  : _result != null
                      ? _buildResult(isDark, cardColor, textColor, subtextColor)
                      : _buildProfileGrid(
                          isDark, cardColor, textColor, subtextColor),
        ),
      ),
    );
  }

  // ── Custom header ──────────────────────────────────────────────────────
  Widget _buildHeader({
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required String title,
    String? subtitle,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: textColor),
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(fontSize: 13, color: subtextColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark, Color textColor, Color subtextColor) {
    return Column(
      children: [
        _buildHeader(
          isDark: isDark,
          textColor: textColor,
          subtextColor: subtextColor,
          title: 'Vente Flash',
          subtitle: 'Chargement...',
          onBack: () => setState(() {
            _selectedSite = null;
            _profiles = [];
            _result = null;
            _error = null;
          }),
        ),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      ],
    );
  }

  // ── 1. Site selector ───────────────────────────────────────────────────
  Widget _buildSiteSelector(List<Site> sites, bool isDark, Color cardColor,
      Color textColor, Color subtextColor) {
    final configured = sites.where((s) => s.isConfigured).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          isDark: isDark,
          textColor: textColor,
          subtextColor: subtextColor,
          title: 'Vente Flash',
          subtitle: 'Choisissez un site',
          onBack: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 8),
        if (configured.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.router_outlined,
                      size: 56, color: subtextColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('Aucun site configure',
                      style: TextStyle(color: subtextColor, fontSize: 15)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: configured.length,
              itemBuilder: (_, i) {
                final site = configured[i];
                final isOnline = site.isOnline;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    elevation: isDark ? 0 : 2,
                    shadowColor: Colors.black.withValues(alpha: 0.06),
                    child: InkWell(
                      onTap: () => _loadProfiles(site),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: isDark
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.darkBorder),
                              )
                            : null,
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: (isOnline
                                        ? AppTheme.success
                                        : AppTheme.danger)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.router_rounded,
                                  color: isOnline
                                      ? AppTheme.success
                                      : AppTheme.danger,
                                  size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(site.nom,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: textColor)),
                                  const SizedBox(height: 3),
                                  Text(site.routerIp,
                                      style: TextStyle(
                                          color: subtextColor, fontSize: 13)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: (isOnline
                                        ? AppTheme.success
                                        : AppTheme.danger)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isOnline ? 'En ligne' : 'Hors ligne',
                                style: TextStyle(
                                  color: isOnline
                                      ? AppTheme.success
                                      : AppTheme.danger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                color: subtextColor, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  // ── 2. Profile grid ────────────────────────────────────────────────────
  Widget _buildProfileGrid(
      bool isDark, Color cardColor, Color textColor, Color subtextColor) {
    final profileColors = [
      AppTheme.primary,
      AppTheme.success,
      AppTheme.accent,
      AppTheme.info,
      AppTheme.danger,
      const Color(0xFF8B5CF6),
    ];

    return Column(
      children: [
        _buildHeader(
          isDark: isDark,
          textColor: textColor,
          subtextColor: subtextColor,
          title: 'Vente Flash',
          subtitle: _selectedSite!.nom,
          onBack: () => setState(() {
            _selectedSite = null;
            _profiles = [];
            _result = null;
            _error = null;
          }),
        ),

        // Site name banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.08),
                AppTheme.primary.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.router_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                _selectedSite!.nom,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),

        // Point dropdown
        if (_points.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE5E7EB),
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: DropdownButtonFormField<int>(
                initialValue: _selectedPointId,
                decoration: InputDecoration(
                  labelText: 'Point de vente',
                  labelStyle: TextStyle(color: subtextColor, fontSize: 14),
                  prefixIcon: const Icon(Icons.storefront_rounded,
                      color: AppTheme.primary, size: 20),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                dropdownColor: cardColor,
                style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                items: _points.map((p) {
                  final id = p['id'] is int
                      ? p['id'] as int
                      : int.tryParse(p['id'].toString()) ?? 0;
                  return DropdownMenuItem(
                      value: id, child: Text(p['name'] ?? ''));
                }).toList(),
                onChanged: (v) => setState(() => _selectedPointId = v),
              ),
            ),
          ),

        // Error message
        if (_error != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style:
                          const TextStyle(color: AppTheme.danger, fontSize: 13)),
                ),
              ],
            ),
          ),

        // Generating indicator
        if (_generating)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                  color: AppTheme.primary, minHeight: 3),
            ),
          ),

        // Profile grid
        Expanded(
          child: _profiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded,
                          size: 48,
                          color: subtextColor.withValues(alpha: 0.4)),
                      const SizedBox(height: 10),
                      Text('Aucun profil disponible',
                          style:
                              TextStyle(color: subtextColor, fontSize: 14)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: _profiles.length,
                  itemBuilder: (_, i) {
                    final p = _profiles[i];
                    final price = p['ticket_price'];
                    final currency = p['currency'] ?? 'XOF';
                    final name = p['name'] ?? '';
                    final validity = p['validity_value'];
                    final unit = p['validity_unit'];
                    final units = {
                      'hours': 'h',
                      'days': 'j',
                      'weeks': 'sem',
                      'months': 'mois'
                    };
                    final duration = validity != null
                        ? '$validity${units[unit] ?? ''}'
                        : 'Illimite';
                    final color =
                        profileColors[i % profileColors.length];

                    return Material(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      elevation: isDark ? 0 : 2,
                      shadowColor: Colors.black.withValues(alpha: 0.06),
                      child: InkWell(
                        onTap: _generating ? null : () => _generate(name),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: isDark
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: AppTheme.darkBorder),
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(Icons.wifi_rounded,
                                    color: color, size: 22),
                              ),
                              const SizedBox(height: 10),
                              Text(name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(duration,
                                  style: TextStyle(
                                      color: subtextColor, fontSize: 12)),
                              if (price != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  Fmt.currency(
                                      num.tryParse('$price') ?? 0, currency),
                                  style: const TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── 3. Result view ─────────────────────────────────────────────────────
  Widget _buildResult(
      bool isDark, Color cardColor, Color textColor, Color subtextColor) {
    final code = _result!['code'] ?? '';
    final password = _result!['password'] ?? '';
    final profile = _result!['profile'] ?? '';
    final price = _result!['price'];
    final currency = _result!['currency'] ?? 'XOF';
    final duration = _result!['duration'] ?? '';
    final siteName = _result!['site_name'] ?? '';

    return Column(
      children: [
        _buildHeader(
          isDark: isDark,
          textColor: textColor,
          subtextColor: subtextColor,
          title: 'Vente Flash',
          subtitle: 'Voucher genere',
          onBack: () => setState(() {
            _result = null;
            _error = null;
          }),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              children: [
                // Success icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: AppTheme.success, size: 44),
                ),
                const SizedBox(height: 14),
                Text('Voucher genere !',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor)),
                const SizedBox(height: 20),

                // Voucher card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: isDark
                        ? Border.all(color: AppTheme.darkBorder)
                        : null,
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(siteName,
                            style:
                                TextStyle(color: subtextColor, fontSize: 13)),
                        const SizedBox(height: 14),

                        // Code display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    AppTheme.primary.withValues(alpha: 0.15)),
                          ),
                          child: Center(
                            child: SelectableText(
                              code,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Password
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : const Color(0xFFF5F6FA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 15, color: subtextColor),
                              const SizedBox(width: 6),
                              Text('Mot de passe: ',
                                  style: TextStyle(
                                      fontSize: 13, color: subtextColor)),
                              Text(password,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Divider
                        Divider(
                            color: isDark
                                ? AppTheme.darkBorder
                                : const Color(0xFFE5E7EB)),
                        const SizedBox(height: 14),

                        // Info chips
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _infoChip(Icons.wifi_rounded, profile,
                                AppTheme.primary, isDark),
                            _infoChip(Icons.timer_outlined, duration,
                                AppTheme.info, isDark),
                            if (price != null)
                              _infoChip(
                                  Icons.payments_outlined,
                                  Fmt.currency(price as num, currency),
                                  AppTheme.success,
                                  isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Material(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: 'Code: $code / Pass: $password'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Copie !'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.copy_rounded,
                                    size: 18, color: textColor),
                                const SizedBox(width: 8),
                                Text('Copier',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                        fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => setState(() {
                            _result = null;
                            _error = null;
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flash_on_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Nouvelle vente',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Info chip (for result view) ────────────────────────────────────────
  Widget _infoChip(IconData icon, String label, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1D21))),
      ],
    );
  }
}
