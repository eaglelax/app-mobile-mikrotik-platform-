import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  List<Map<String, dynamic>> _salesHistory = [];
  bool _loadingHistory = false;
  String _searchQuery = '';
  bool _isGerant = false;
  bool _gerantInitDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_gerantInitDone) {
      _gerantInitDone = true;
      final auth = context.read<AuthProvider>();
      final user = auth.user;
      if (user != null && user.isGerant && user.siteId != null) {
        _isGerant = true;
        _loadGerantProfiles(user.siteId!, user.pointId);
      }
    }
  }

  Future<void> _loadGerantProfiles(int siteId, int? pointId) async {
    setState(() { _loadingProfiles = true; _error = null; });
    try {
      final data = await _api.getCached(ApiConfig.flashSale,
          params: {'site_id': siteId.toString()},
          ttl: const Duration(seconds: 30));
      if (data['success'] == true) {
        final list = data['profiles'] as List? ?? [];
        setState(() {
          _profiles = list.map((p) => Map<String, dynamic>.from(p)).toList();
          _selectedPointId = pointId;
          _selectedSite = Site(id: siteId, nom: data['site_name'] ?? 'Mon site', routerIp: '', routerStatus: 'online');
        });
      } else {
        setState(() => _error = data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loadingProfiles = false);
    if (_selectedSite != null) _loadHistory(_selectedSite!);
  }

  void _reset() {
    if (_isGerant) {
      setState(() { _result = null; _error = null; });
      return;
    }
    setState(() {
      _selectedSite = null;
      _profiles = [];
      _result = null;
      _error = null;
      _salesHistory = [];
      _searchQuery = '';
    });
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
      final data = await _api.getCached(ApiConfig.flashSale,
          params: {'site_id': site.id.toString()},
          ttl: const Duration(seconds: 30));
      if (data['success'] == true) {
        final list = data['profiles'] as List? ?? [];
        final pts = data['points'] as List? ?? [];
        setState(() {
          _profiles = list.map((p) => Map<String, dynamic>.from(p)).toList();
          _points = pts.map((p) => Map<String, dynamic>.from(p)).toList();
          _selectedPointId = _points.isNotEmpty
              ? (_points.first['id'] is int ? _points.first['id'] : int.tryParse(_points.first['id'].toString()))
              : null;
        });
      } else {
        setState(() => _error = data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loadingProfiles = false);
    _loadHistory(site);
  }

  Future<void> _loadHistory(Site site) async {
    setState(() => _loadingHistory = true);
    try {
      final data = await _api.get(ApiConfig.flashSale, {
        'site_id': site.id.toString(),
        'action': 'history',
      });
      if (data['success'] == true) {
        setState(() {
          _salesHistory = ((data['sales'] ?? data['history'] ?? []) as List)
              .map((s) => Map<String, dynamic>.from(s))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingHistory = false);
  }

  Future<void> _generate(String profileName) async {
    if (_selectedSite == null || _generating) return;
    setState(() { _generating = true; _result = null; _error = null; });
    try {
      final data = await _api.post(ApiConfig.flashSale, {
        'site_id': _selectedSite!.id,
        'profile': profileName,
        if (_selectedPointId != null) 'point_id': _selectedPointId,
      });
      if (data['success'] == true) {
        setState(() => _result = data);
        _loadHistory(_selectedSite!);
      } else {
        setState(() => _error = data['error'] ?? 'Erreur génération');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sites = _isGerant ? <Site>[] : context.watch<SiteProvider>().sites;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final card = isDark ? AppTheme.darkCard : Colors.white;

    return PopScope(
      canPop: _isGerant || _selectedSite == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_result != null) {
            setState(() { _result = null; _error = null; });
          } else {
            _reset();
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        body: SafeArea(
          child: _selectedSite == null
              ? _siteSelector(sites, isDark, card, textColor, sub)
              : _loadingProfiles
                  ? _loading(textColor, sub)
                  : _result != null
                      ? _resultView(isDark, card, textColor, sub)
                      : _profileView(isDark, card, textColor, sub),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LOADING
  // ═══════════════════════════════════════════════════════════════════════
  Widget _loading(Color textColor, Color sub) {
    return Column(
      children: [
        if (!_isGerant)
          _header('Vente Flash', 'Chargement...', textColor, sub, onBack: _reset),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════
  Widget _header(String title, String? subtitle, Color textColor, Color sub, {required VoidCallback onBack}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor), onPressed: onBack),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 13, color: sub)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 1. SITE SELECTOR
  // ═══════════════════════════════════════════════════════════════════════
  Widget _siteSelector(List<Site> sites, bool isDark, Color card, Color text, Color sub) {
    final configured = sites.where((s) => s.isConfigured).toList();
    final q = _searchQuery.toLowerCase();
    final filtered = q.isEmpty ? configured : configured.where((s) => s.nom.toLowerCase().contains(q) || s.routerIp.contains(q)).toList();
    final sh = _sh(isDark);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.flash_on, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vente Flash', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: text)),
                    Text('Choisir un site', style: TextStyle(fontSize: 13, color: sub)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Container(
            height: 46,
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(23), boxShadow: sh),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Rechercher un site...',
                hintStyle: TextStyle(color: sub, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: sub, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (configured.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.router_outlined, size: 48, color: sub.withValues(alpha: 0.4)),
                  const SizedBox(height: 10),
                  Text('Aucun site configuré', style: TextStyle(color: sub, fontSize: 14)),
                ],
              ),
            ),
          )
        else if (filtered.isEmpty)
          Expanded(child: Center(child: Text('Aucun résultat pour "$_searchQuery"', style: TextStyle(color: sub, fontSize: 14))))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final site = filtered[i];
                final on = site.isOnline;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: () => _loadProfiles(site),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: sh),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(13)),
                                  child: const Icon(Icons.router_rounded, color: AppTheme.primary, size: 22),
                                ),
                                Positioned(
                                  right: 0, top: 0,
                                  child: Container(
                                    width: 12, height: 12,
                                    decoration: BoxDecoration(
                                      color: on ? AppTheme.success : AppTheme.danger,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: card, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(site.nom, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: text)),
                                  const SizedBox(height: 2),
                                  Text(site.routerIp, style: TextStyle(color: sub, fontSize: 12)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 20, color: sub),
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

  // ═══════════════════════════════════════════════════════════════════════
  // 2. PROFILE VIEW — redesigned
  // ═══════════════════════════════════════════════════════════════════════
  Widget _profileView(bool isDark, Color card, Color text, Color sub) {
    final sh = _sh(isDark);
    final divCol = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Column(
      children: [
        // ── Header ──
        if (_isGerant)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vente Flash', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: text)),
                      Text(_selectedSite!.nom, style: TextStyle(fontSize: 12, color: sub)),
                    ],
                  ),
                ),
                // Refresh button
                IconButton(
                  onPressed: () => _loadHistory(_selectedSite!),
                  icon: Icon(Icons.refresh_rounded, size: 20, color: sub),
                  tooltip: 'Actualiser',
                ),
              ],
            ),
          )
        else
          _header('Vente Flash', _selectedSite!.nom, text, sub, onBack: _reset),

        // ── Point de vente (admin only) ──
        if (!_isGerant && _points.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), boxShadow: sh),
              child: DropdownButtonFormField<int>(
                initialValue: _selectedPointId,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.storefront_rounded, color: AppTheme.primary, size: 18),
                  labelText: 'Point de vente',
                  labelStyle: TextStyle(color: sub, fontSize: 13),
                  border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                dropdownColor: card,
                style: TextStyle(color: text, fontSize: 14),
                items: _points.map((p) {
                  final id = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0;
                  return DropdownMenuItem(value: id, child: Text(p['name'] ?? ''));
                }).toList(),
                onChanged: (v) => setState(() => _selectedPointId = v),
              ),
            ),
          ),

        // ── Error ──
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
                ],
              ),
            ),
          ),

        // ── Generating indicator ──
        if (_generating)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(borderRadius: BorderRadius.circular(2), child: const LinearProgressIndicator(color: AppTheme.primary, minHeight: 3)),
          ),

        // ── Content ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              if (_selectedSite != null) {
                await Future.wait([
                  _loadGerantProfiles(_selectedSite!.id, _selectedPointId),
                ]);
              }
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                // ── Profile cards: grid 3 columns ──
                if (_profiles.isEmpty)
                  _emptyState(Icons.wifi_off_rounded, 'Aucun profil disponible', sub)
                else ...[
                  Row(
                    children: [
                      Text('Générer un voucher', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                      const Spacer(),
                      Text('${_profiles.length} profils', style: TextStyle(fontSize: 12, color: sub)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _profiles.length,
                    itemBuilder: (_, i) {
                      final p = _profiles[i];
                      final price = p['ticket_price'];
                      final currency = p['currency'] ?? 'XOF';
                      final name = p['name'] ?? '';
                      final validity = p['validity_value'];
                      final unit = p['validity_unit'];
                      final uMap = {'hours': 'h', 'days': 'j', 'weeks': 'sem', 'months': 'mois'};
                      final dur = validity != null ? '$validity${uMap[unit] ?? ''}' : 'Illimité';

                      return Material(
                        color: card,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _generating ? null : () => _generate(name),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: sh,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(Icons.wifi_rounded, color: AppTheme.primary, size: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: text),
                                  maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.info.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(dur, style: const TextStyle(color: AppTheme.info, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                                if (price != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    Fmt.currency(num.tryParse('$price') ?? 0, currency),
                                    style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                const SizedBox(height: 20),

                // ── History ──
                Row(
                  children: [
                    Text('Historique du jour', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                    const Spacer(),
                    if (_loadingHistory)
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 10),

                if (_loadingHistory && _salesHistory.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_salesHistory.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: sh,
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 40, color: sub.withValues(alpha: 0.3)),
                        const SizedBox(height: 10),
                        Text("Aucune vente aujourd'hui", style: TextStyle(color: sub, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Les ventes apparaîtront ici', style: TextStyle(color: sub.withValues(alpha: 0.6), fontSize: 11)),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), boxShadow: sh),
                    child: Column(
                      children: List.generate(_salesHistory.length, (i) {
                        final s = _salesHistory[i];
                        final code = s['code'] ?? s['user'] ?? s['name'] ?? '';
                        final prof = s['profile'] ?? '';
                        final pr = s['price'] ?? s['ticket_price'];
                        final time = s['time'] ?? s['created_at'] ?? '';

                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _showSaleDetail(s),
                              borderRadius: i == 0
                                  ? const BorderRadius.vertical(top: Radius.circular(16))
                                  : i == _salesHistory.length - 1
                                      ? const BorderRadius.vertical(bottom: Radius.circular(16))
                                      : BorderRadius.zero,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Index circle
                                    Container(
                                      width: 34, height: 34,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : const Color(0xFFF0F4FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            code,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: text,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  prof,
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary.withValues(alpha: 0.8)),
                                                ),
                                              ),
                                              if (time.toString().isNotEmpty) ...[
                                                const SizedBox(width: 6),
                                                Text(time.toString(), style: TextStyle(fontSize: 11, color: sub)),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (pr != null)
                                      Text(
                                        Fmt.currency(num.tryParse('$pr') ?? 0),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.success),
                                      ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.chevron_right_rounded, size: 18, color: sub.withValues(alpha: 0.5)),
                                  ],
                                ),
                              ),
                            ),
                            if (i < _salesHistory.length - 1)
                              Padding(padding: const EdgeInsets.only(left: 62), child: Divider(height: 1, color: divCol)),
                          ],
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 3. RESULT VIEW
  // ═══════════════════════════════════════════════════════════════════════
  Widget _resultView(bool isDark, Color card, Color text, Color sub) {
    final code = _result!['code'] ?? '';
    final password = _result!['password'] ?? '';
    final profile = _result!['profile'] ?? '';
    final price = _result!['price'];
    final currency = _result!['currency'] ?? 'XOF';
    final duration = _result!['duration'] ?? '';
    final sh = _sh(isDark);

    return Column(
      children: [
        // Minimal header — just back arrow
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: text),
                onPressed: () => setState(() { _result = null; _error = null; }),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              children: [
                // Success animation
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 36),
                ),
                const SizedBox(height: 12),
                Text('Voucher généré', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: text)),
                if (price != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    Fmt.currency(price as num, currency),
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.success),
                  ),
                ],
                const SizedBox(height: 24),

                // Voucher card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: sh,
                  ),
                  child: Column(
                    children: [
                      // QR Code
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: QrImageView(
                          data: 'Code: $code | Pass: $password | Profil: $profile',
                          version: QrVersions.auto,
                          size: 160,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1D21)),
                          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1D21)),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Dashed divider effect
                      Row(
                        children: List.generate(30, (i) => Expanded(
                          child: Container(
                            height: 1,
                            color: i.isEven ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200) : Colors.transparent,
                          ),
                        )),
                      ),
                      const SizedBox(height: 20),

                      // Code
                      Text('CODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sub, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      SelectableText(
                        code,
                        style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 4, color: text),
                      ),
                      const SizedBox(height: 12),

                      // Password
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline, size: 14, color: sub),
                            const SizedBox(width: 6),
                            Text('Mot de passe:  ', style: TextStyle(fontSize: 12, color: sub)),
                            Text(password, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _tag(profile, AppTheme.primary),
                          const SizedBox(width: 8),
                          _tag(duration, const Color(0xFF7C3AED)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: 'Code: $code / Pass: $password'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Copié dans le presse-papier'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          icon: Icon(Icons.copy_rounded, size: 18, color: text),
                          label: Text('Copier', style: TextStyle(fontWeight: FontWeight.w600, color: text)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => setState(() { _result = null; _error = null; }),
                          icon: const Icon(Icons.flash_on_rounded, size: 18),
                          label: const Text('Nouvelle vente', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════
  List<BoxShadow> _sh(bool isDark) => isDark
      ? []
      : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _chip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _showSaleDetail(Map<String, dynamic> s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF1A1D21);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final card = isDark ? AppTheme.darkCard : Colors.white;
    final code = s['code'] ?? s['user'] ?? s['name'] ?? '';
    final prof = s['profile'] ?? '';
    final pr = s['price'] ?? s['ticket_price'];
    final time = s['time'] ?? s['created_at'] ?? '';
    final date = s['sale_date'] ?? '';
    final password = code;

    final qrData = 'Code: $code | Pass: $password | Profil: $prof';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1D21)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1D21)),
              ),
            ),
            const SizedBox(height: 16),
            Text(code, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3, color: text)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chip(prof, AppTheme.primary, isDark),
                if (pr != null) ...[
                  const SizedBox(width: 8),
                  _chip(Fmt.currency(num.tryParse('$pr') ?? 0), AppTheme.success, isDark),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (date.toString().isNotEmpty || time.toString().isNotEmpty)
              Text(
                '${date.toString().isNotEmpty ? date : ''}${time.toString().isNotEmpty ? '  ·  $time' : ''}',
                style: TextStyle(fontSize: 13, color: sub),
              ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'Code: $code / Pass: $password'));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Copié !'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copier le code', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String text, Color sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 36, color: sub.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: sub, fontSize: 13)),
        ],
      ),
    );
  }
}
