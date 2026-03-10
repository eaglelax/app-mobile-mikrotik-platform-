import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
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

  void _reset() {
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
      final data = await _api.get(ApiConfig.flashSale, {'site_id': site.id.toString()});
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
    final sites = context.watch<SiteProvider>().sites;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final card = isDark ? AppTheme.darkCard : Colors.white;

    return PopScope(
      canPop: _selectedSite == null,
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
        // Header without back (it's a tab)
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
                    Text('Générer un voucher en 1 clic', style: TextStyle(fontSize: 13, color: sub)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Search
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

        // Sites
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
                            // Status dot + icon
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
  // 2. PROFILE VIEW (grid + history)
  // ═══════════════════════════════════════════════════════════════════════
  Widget _profileView(bool isDark, Color card, Color text, Color sub) {
    final colors = [AppTheme.primary, AppTheme.success, AppTheme.accent, AppTheme.info, const Color(0xFF8B5CF6), AppTheme.danger];
    final sh = _sh(isDark);
    final div = isDark ? Colors.grey.shade800 : Colors.grey.shade200;

    return Column(
      children: [
        _header('Vente Flash', _selectedSite!.nom, text, sub, onBack: _reset),

        // Point de vente
        if (_points.isNotEmpty)
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

        // Error
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

        // Progress
        if (_generating)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(borderRadius: BorderRadius.circular(2), child: const LinearProgressIndicator(color: AppTheme.primary, minHeight: 3)),
          ),

        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Section label
              Text('Choisir un profil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sub)),
              const SizedBox(height: 10),

              if (_profiles.isEmpty)
                _emptyState(Icons.wifi_off_rounded, 'Aucun profil disponible', sub)
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.95,
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
                    final c = colors[i % colors.length];

                    return Material(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _generating ? null : () => _generate(name),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: sh),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                                child: Icon(Icons.wifi_rounded, color: c, size: 24),
                              ),
                              const SizedBox(height: 10),
                              Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: text), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                                child: Text(dur, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                              if (price != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  Fmt.currency(num.tryParse('$price') ?? 0, currency),
                                  style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800, fontSize: 16),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 28),

              // History
              Row(
                children: [
                  Icon(Icons.history_rounded, size: 18, color: sub),
                  const SizedBox(width: 6),
                  Text('Historique du jour', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sub)),
                  const Spacer(),
                  if (!_loadingHistory)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('${_salesHistory.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accent)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (_loadingHistory)
                const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_salesHistory.isEmpty)
                _emptyState(Icons.receipt_long_outlined, 'Aucune vente aujourd\'hui', sub)
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
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                                  child: const Icon(Icons.flash_on, size: 15, color: AppTheme.accent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(code, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text, letterSpacing: 0.3)),
                                      Text('$prof${time.toString().isNotEmpty ? '  ·  $time' : ''}', style: TextStyle(fontSize: 11, color: sub)),
                                    ],
                                  ),
                                ),
                                if (pr != null)
                                  Text(Fmt.currency(num.tryParse('$pr') ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success)),
                              ],
                            ),
                          ),
                          if (i < _salesHistory.length - 1)
                            Padding(padding: const EdgeInsets.only(left: 60), child: Divider(height: 1, color: div)),
                        ],
                      );
                    }),
                  ),
                ),
            ],
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
    final siteName = _result!['site_name'] ?? '';
    final sh = _sh(isDark);

    return Column(
      children: [
        _header('Voucher généré', siteName, text, sub, onBack: () => setState(() { _result = null; _error = null; })),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                // Main voucher card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), boxShadow: sh),
                  child: Column(
                    children: [
                      // Top gradient strip
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF7C3AED)]),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 28),
                            const SizedBox(height: 6),
                            const Text('Voucher généré avec succès', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            if (price != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(Fmt.currency(price as num, currency), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                              ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // QR Code
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                              child: QrImageView(
                                data: 'Code: $code | Pass: $password | Profil: $profile',
                                version: QrVersions.auto,
                                size: 150,
                                backgroundColor: Colors.white,
                                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1D21)),
                                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1D21)),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Code
                            Text('CODE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sub, letterSpacing: 1.5)),
                            const SizedBox(height: 6),
                            SelectableText(
                              code,
                              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 4, color: text),
                            ),

                            const SizedBox(height: 12),

                            // Password chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_outline, size: 14, color: sub),
                                  const SizedBox(width: 6),
                                  Text('MDP: ', style: TextStyle(fontSize: 13, color: sub)),
                                  Text(password, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Info row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _chip(profile, AppTheme.primary, isDark),
                                const SizedBox(width: 8),
                                _chip(duration, AppTheme.info, isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: 'Code: $code / Pass: $password'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Copié !'), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
                        height: 50,
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

  Widget _chip(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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
