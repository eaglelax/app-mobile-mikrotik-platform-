import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../models/point.dart';
import '../../providers/site_provider.dart';
import '../../services/mikhmon_service.dart';
import '../../services/ticket_service.dart';
import '../../services/point_service_api.dart';

class VouchersScreen extends StatefulWidget {
  final Site? site;
  const VouchersScreen({super.key, this.site});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final _service = MikhmonService();
  final _ticketService = TicketService();
  final _pointApi = PointServiceApi();
  Site? _site;
  List<Map<String, dynamic>> _vouchers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _error;
  String? _profileFilter;
  String _search = '';
  String _siteSearch = '';
  final _siteSearchController = TextEditingController();
  Timer? _autoRefreshTimer;

  // Generation state
  List<Map<String, dynamic>> _profiles = [];
  List<Point> _points = [];
  bool _loadingProfiles = false;

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site != null) {
      _load();
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _siteSearchController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && _site != null && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) _load();
    });
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchVouchers(_site!.id);
      if (data['success'] == false) {
        _error = data['error']?.toString() ?? 'Erreur inconnue';
        _vouchers = [];
      } else {
        _vouchers =
            (data['vouchers'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      _applyFilters();
    } catch (e) {
      _error = 'Connexion echouee: ${e.toString().length > 80 ? e.toString().substring(0, 80) : e}';
      _vouchers = [];
      _applyFilters();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    var list = _vouchers;
    if (_profileFilter != null) {
      list = list.where((v) => v['profile'] == _profileFilter).toList();
    }
    if (_search.isNotEmpty) {
      final s = _search.toLowerCase();
      list = list
          .where((v) =>
              (v['name'] ?? '').toString().toLowerCase().contains(s) ||
              (v['profile'] ?? '').toString().toLowerCase().contains(s))
          .toList();
    }
    _filtered = list;
  }

  Set<String> get _profileNames =>
      _vouchers.map((v) => (v['profile'] ?? '').toString()).toSet();

  Future<void> _loadProfiles() async {
    if (_site == null) return;
    setState(() => _loadingProfiles = true);
    try {
      final results = await Future.wait([
        _service.fetchProfiles(_site!.id),
        _pointApi.fetchBySite(_site!.id),
      ]);
      final profileData = results[0] as Map<String, dynamic>;
      if (profileData['success'] == true) {
        _profiles = (profileData['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      _points = results[1] as List<Point>;
    } catch (_) {}
    if (mounted) setState(() => _loadingProfiles = false);
  }

  void _showGenerateDialog() async {
    if (_profiles.isEmpty) await _loadProfiles();
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Map<String, dynamic>? selectedProfile;
    Point? selectedPoint;
    final qtyController = TextEditingController(text: '10');
    bool generating = false;
    final activePoints = _points.where((p) => p.isActive).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  Text('Generer des tickets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF1A1D21))),
                  const SizedBox(height: 4),
                  Text('Les tickets seront crees sur le routeur hotspot', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),

                  // Profile
                  Text('Profil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  if (_loadingProfiles)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (_profiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('Aucun profil disponible', style: TextStyle(fontSize: 13))),
                        GestureDetector(
                          onTap: () { _loadProfiles().then((_) { if (mounted) setSheetState(() {}); }); },
                          child: const Icon(Icons.refresh, size: 18),
                        ),
                      ]),
                    )
                  else
                    _genDropdown(isDark,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedProfile?['name'],
                          hint: Text('Choisir un profil', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                          items: _profiles.map((p) {
                            final name = p['name'] ?? '';
                            final price = p['ticket_price'];
                            final stock = p['stock'];
                            final stockLabel = stock != null ? ' ($stock)' : '';
                            final priceLabel = price != null && price > 0 ? ' - ${price.toStringAsFixed(0)} FCFA' : '';
                            return DropdownMenuItem(value: name as String, child: Text('$name$priceLabel$stockLabel', style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) {
                            setSheetState(() {
                              selectedProfile = _profiles.firstWhere((p) => p['name'] == val);
                              final suggestion = selectedProfile?['suggestion'];
                              if (suggestion != null && suggestion > 0) qtyController.text = suggestion.toString();
                            });
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Point de vente
                  Text('Point de vente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  if (activePoints.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text('Aucun point de vente configure', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                      ]),
                    )
                  else
                    _genDropdown(isDark,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedPoint?.id,
                          hint: Text('Tous (optionnel)', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                          items: [
                            DropdownMenuItem<int>(value: null, child: Text('Tous les points', style: TextStyle(fontSize: 14, color: Colors.grey.shade400))),
                            ...activePoints.map((p) {
                              final serverLabel = p.serverName != null ? ' (${p.serverName})' : '';
                              return DropdownMenuItem<int>(value: p.id, child: Text('${p.name}$serverLabel', style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87), overflow: TextOverflow.ellipsis));
                            }),
                          ],
                          onChanged: (val) {
                            setSheetState(() { selectedPoint = val != null ? activePoints.firstWhere((p) => p.id == val) : null; });
                          },
                        ),
                      ),
                    ),

                  if (selectedPoint?.serverName != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.wifi, size: 14, color: AppTheme.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text('Serveur hotspot: ${selectedPoint!.serverName}', style: TextStyle(fontSize: 12, color: AppTheme.primary.withValues(alpha: 0.7))),
                    ]),
                  ],

                  const SizedBox(height: 16),

                  // Quantity
                  Text('Quantite', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Row(children: [
                    _qtyBtn(Icons.remove, () {
                      final c = int.tryParse(qtyController.text) ?? 10;
                      if (c > 1) setSheetState(() => qtyController.text = (c - 5).clamp(1, 2000).toString());
                    }, isDark),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: qtyController, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(filled: true, fillColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    )),
                    const SizedBox(width: 12),
                    _qtyBtn(Icons.add, () {
                      final c = int.tryParse(qtyController.text) ?? 10;
                      setSheetState(() => qtyController.text = (c + 5).clamp(1, 2000).toString());
                    }, isDark),
                  ]),

                  const SizedBox(height: 24),

                  // Generate button
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: (generating || selectedProfile == null) ? null : () async {
                        final qty = int.tryParse(qtyController.text) ?? 0;
                        if (qty < 1 || qty > 2000) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Quantite entre 1 et 2000')));
                          return;
                        }
                        setSheetState(() => generating = true);
                        try {
                          final result = await _ticketService.generateBatch(_site!.id, profile: selectedProfile!['name'] as String, quantity: qty, pointId: selectedPoint?.id);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          final generated = result['generated'] ?? result['quantity'] ?? qty;
                          final synced = result['synced'] ?? 0;
                          final failed = result['failed'] ?? 0;
                          final syncMode = result['sync_mode'] ?? 'sync';
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: AppTheme.success,
                            content: Text(syncMode == 'background' ? '$generated tickets generes, synchro en cours...' : '$generated tickets generes ($synced synchro${failed > 0 ? ', $failed echoues' : ''})', style: const TextStyle(color: Colors.white)),
                          ));
                          _load();
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setSheetState(() => generating = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(backgroundColor: AppTheme.danger, content: Text('Erreur: $e', style: const TextStyle(color: Colors.white))));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      child: generating
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Generer les tickets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _genDropdown(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
      child: child,
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.grey.shade700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);

    if (_site == null) {
      return _buildSiteSelector(context, isDark, bg);
    }

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _autoRefreshTimer?.cancel();
          setState(() {
            _site = null;
            _vouchers = [];
            _filtered = [];
          });
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showGenerateDialog,
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Generer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppTheme.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // -- Header --
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back,
                              color: isDark ? Colors.white : Colors.black87),
                          onPressed: () {
                            if (widget.site != null) {
                              Navigator.pop(context);
                            } else {
                              _autoRefreshTimer?.cancel();
                              setState(() {
                                _site = null;
                                _vouchers = [];
                                _filtered = [];
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vouchers (${_filtered.length})',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                _site!.nom,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_loading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          GestureDetector(
                            onTap: _load,
                            child: Icon(Icons.refresh,
                                color: isDark ? Colors.white70 : Colors.grey.shade600, size: 22),
                          ),
                      ],
                    ),
                  ),
                ),

                // -- Search bar --
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: TextField(
                      onChanged: (v) {
                        setState(() {
                          _search = v;
                          _applyFilters();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Rechercher un voucher...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search,
                            color: Colors.grey.shade400, size: 20),
                        filled: true,
                        fillColor: isDark ? AppTheme.darkCard : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(50),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),

                // -- Profile filter chips --
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        _buildChip('Tous', _profileFilter == null, () {
                          setState(() {
                            _profileFilter = null;
                            _applyFilters();
                          });
                        }, isDark),
                        ..._profileNames.map((p) => _buildChip(
                              p,
                              _profileFilter == p,
                              () {
                                setState(() {
                                  _profileFilter = p;
                                  _applyFilters();
                                });
                              },
                              isDark,
                            )),
                      ],
                    ),
                  ),
                ),

                // -- Error banner --
                if (_error != null)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
                          ),
                          GestureDetector(
                            onTap: _load,
                            child: const Icon(Icons.refresh, color: AppTheme.danger, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),

                // -- Content --
                if (_loading && _vouchers.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_filtered.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.confirmation_number_outlined,
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun voucher',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final v = _filtered[i];
                          final disabled =
                              v['disabled'] == 'true' || v['disabled'] == true;
                          final statusColor =
                              disabled ? Colors.grey : AppTheme.success;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color:
                                        statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.confirmation_number,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v['name'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                          letterSpacing: 1.2,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Profil: ${v['profile'] ?? '-'}  ${v['limit-uptime'] ?? ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    disabled ? 'Utilis\u00e9' : 'Disponible',
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -- Site selector view --
  Widget _buildSiteSelector(BuildContext context, bool isDark, Color bg) {
    final sites = context.watch<SiteProvider>().configuredSites;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: isDark ? Colors.white : Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vouchers',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Choisissez un site',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: isDark ? null : [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
                  ],
                ),
                child: TextField(
                  controller: _siteSearchController,
                  onChanged: (v) => setState(() => _siteSearch = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un site...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 18, right: 8),
                      child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: _siteSearch.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
                              onPressed: () { _siteSearchController.clear(); setState(() => _siteSearch = ''); },
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sites.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun site configur\u00e9',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final filtered = sites.where((s) {
                          if (_siteSearch.isEmpty) return true;
                          final q = _siteSearch.toLowerCase();
                          return s.nom.toLowerCase().contains(q) || s.routerIp.toLowerCase().contains(q);
                        }).toList();
                        return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final s = filtered[i];
                        return GestureDetector(
                          onTap: () {
                            setState(() => _site = s);
                            _load();
                            _startAutoRefresh();
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.router,
                                      color: AppTheme.primary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.nom,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        s.routerIp,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right,
                                    color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Custom chip --
  Widget _buildChip(String label, bool selected, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primary.withValues(alpha: 0.15)
                : (isDark ? AppTheme.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppTheme.primary : Colors.transparent,
                width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppTheme.primary : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}
