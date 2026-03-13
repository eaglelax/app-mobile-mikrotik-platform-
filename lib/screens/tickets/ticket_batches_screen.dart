import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../models/point.dart';
import '../../providers/site_provider.dart';
import '../../services/ticket_service.dart';
import '../../services/mikhmon_service.dart';
import '../../services/point_service_api.dart';

class TicketBatchesScreen extends StatefulWidget {
  final Site? site;
  const TicketBatchesScreen({super.key, this.site});

  @override
  State<TicketBatchesScreen> createState() => _TicketBatchesScreenState();
}

class _TicketBatchesScreenState extends State<TicketBatchesScreen> {
  final _service = TicketService();
  final _mikhmon = MikhmonService();
  final _pointApi = PointServiceApi();
  Site? _site;
  List<Map<String, dynamic>> _batches = [];
  bool _loading = false;
  String? _error;
  String _search = '';
  final _searchController = TextEditingController();
  Timer? _debounce;
  Timer? _autoRefresh;
  String _siteSearch = '';
  final _siteSearchController = TextEditingController();

  // Generation state
  List<Map<String, dynamic>> _profiles = [];
  List<Point> _points = [];
  List<Map<String, dynamic>> _servers = [];
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
    _autoRefresh?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _siteSearchController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) _load();
    });
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.fetchBatches(_site!.id);
      if (data['success'] == true) {
        _batches = (data['batches'] as List? ?? []).cast<Map<String, dynamic>>();
      } else {
        _batches = [];
        _error = data['error']?.toString();
      }
    } catch (e) {
      _batches = [];
      _error = 'Erreur: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfiles() async {
    if (_site == null) return;
    setState(() => _loadingProfiles = true);
    try {
      final results = await Future.wait([
        _mikhmon.fetchProfiles(_site!.id),
        _pointApi.fetchBySite(_site!.id),
        _mikhmon.fetchServers(_site!.id),
      ]);
      final profileData = results[0] as Map<String, dynamic>;
      if (profileData['success'] == true) {
        _profiles = (profileData['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      _points = results[1] as List<Point>;
      final serverData = results[2] as Map<String, dynamic>;
      if (serverData['success'] == true) {
        _servers = (serverData['servers'] as List? ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingProfiles = false);
  }

  List<Map<String, dynamic>> get _filteredBatches {
    if (_search.isEmpty) return _batches;
    final q = _search.toLowerCase();
    return _batches.where((b) =>
        (b['profile_name'] ?? b['profile'] ?? '').toString().toLowerCase().contains(q) ||
        (b['point_name'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  void _showGenerateDialog() async {
    if (_profiles.isEmpty) await _loadProfiles();

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Map<String, dynamic>? selectedProfile;
    Point? selectedPoint;
    final qtyController = TextEditingController(text: '10');
    bool generating = false;

    // Filter active points only
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
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text('Generer des tickets',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1D21),
                      )),
                  const SizedBox(height: 4),
                  Text('Les tickets seront crees sur le routeur hotspot',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),

                  // Profile selector
                  Text('Profil', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  )),
                  const SizedBox(height: 8),
                  if (_loadingProfiles)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else if (_profiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                    _dropdownContainer(isDark,
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
                            return DropdownMenuItem(
                              value: name as String,
                              child: Text('$name$priceLabel$stockLabel',
                                  style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setSheetState(() {
                              selectedProfile = _profiles.firstWhere((p) => p['name'] == val);
                              final suggestion = selectedProfile?['suggestion'];
                              if (suggestion != null && suggestion > 0) {
                                qtyController.text = suggestion.toString();
                              }
                            });
                          },
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Point de vente selector
                  Text('Point de vente', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  )),
                  const SizedBox(height: 8),
                  if (activePoints.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.grey.shade800 : const Color(0xFFF5F6FA)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                        const SizedBox(width: 8),
                        Text('Aucun point de vente configure', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                      ]),
                    )
                  else
                    _dropdownContainer(isDark,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedPoint?.id,
                          hint: Text('Tous (optionnel)', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                          dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                          items: [
                            DropdownMenuItem<int>(
                              value: null,
                              child: Text('Tous les points', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                            ),
                            ...activePoints.map((p) {
                              final serverLabel = p.serverName != null ? ' (${p.serverName})' : '';
                              return DropdownMenuItem<int>(
                                value: p.id,
                                child: Text('${p.name}$serverLabel',
                                    style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                    overflow: TextOverflow.ellipsis),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setSheetState(() {
                              selectedPoint = val != null
                                  ? activePoints.firstWhere((p) => p.id == val)
                                  : null;
                            });
                          },
                        ),
                      ),
                    ),

                  // Show associated hotspot server info
                  if (selectedPoint?.serverName != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.wifi, size: 14, color: AppTheme.primary.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text('Serveur hotspot: ${selectedPoint!.serverName}',
                          style: TextStyle(fontSize: 12, color: AppTheme.primary.withValues(alpha: 0.7))),
                    ]),
                  ],

                  const SizedBox(height: 16),

                  // Quantity input
                  Text('Quantite', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                  )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _qtyButton(Icons.remove, () {
                        final current = int.tryParse(qtyController.text) ?? 10;
                        if (current > 1) {
                          setSheetState(() => qtyController.text = (current - 5).clamp(1, 2000).toString());
                        }
                      }, isDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _qtyButton(Icons.add, () {
                        final current = int.tryParse(qtyController.text) ?? 10;
                        setSheetState(() => qtyController.text = (current + 5).clamp(1, 2000).toString());
                      }, isDark),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (generating || selectedProfile == null)
                          ? null
                          : () async {
                              final qty = int.tryParse(qtyController.text) ?? 0;
                              if (qty < 1 || qty > 2000) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Quantite entre 1 et 2000')),
                                );
                                return;
                              }
                              setSheetState(() => generating = true);
                              try {
                                final profileName = selectedProfile!['name'] as String;
                                final result = await _service.generateBatch(
                                  _site!.id,
                                  profile: profileName,
                                  quantity: qty,
                                  pointId: selectedPoint?.id,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                final generated = result['generated'] ?? result['quantity'] ?? qty;
                                final synced = result['synced'] ?? 0;
                                final failed = result['failed'] ?? 0;
                                final syncMode = result['sync_mode'] ?? 'sync';
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.success,
                                    content: Text(
                                      syncMode == 'background'
                                          ? '$generated tickets generes, synchro en cours...'
                                          : '$generated tickets generes ($synced synchro${failed > 0 ? ', $failed echoues' : ''})',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                );
                                _load();
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setSheetState(() => generating = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.danger,
                                    content: Text('Erreur: $e', style: const TextStyle(color: Colors.white)),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
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

  Widget _dropdownContainer(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.grey.shade700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);

    if (_site == null) {
      return _buildSiteSelector(isDark, bg);
    }

    return _buildBatchesList(isDark, bg);
  }

  // ── Site Selector View ──────────────────────────────────────────────

  Widget _buildSiteSelector(bool isDark, Color bg) {
    final siteProv = context.watch<SiteProvider>();
    final sites = siteProv.configuredSites;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: isDark ? Colors.white : const Color(0xFF1A1D21)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lots de Tickets',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1A1D21),
                              )),
                          Text('Choisissez un site',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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

              // Site cards
              Expanded(
                child: siteProv.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : sites.isEmpty
                        ? Center(
                            child: Text('Aucun site configure',
                                style: TextStyle(color: Colors.grey.shade500)))
                        : Builder(
                            builder: (context) {
                              final filtered = sites.where((s) {
                                if (_siteSearch.isEmpty) return true;
                                final q = _siteSearch.toLowerCase();
                                return s.nom.toLowerCase().contains(q) || s.routerIp.toLowerCase().contains(q);
                              }).toList();
                              return RefreshIndicator(
                            onRefresh: () => siteProv.fetchSites(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final site = filtered[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _site = site);
                                      _load();
                                      _startAutoRefresh();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isDark ? AppTheme.darkCard : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.router,
                                                color: AppTheme.primary, size: 24),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(site.nom,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark
                                                          ? Colors.white
                                                          : const Color(0xFF1A1D21),
                                                    )),
                                                const SizedBox(height: 3),
                                                Text(site.routerIp,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade500,
                                                    )),
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right,
                                              color: Colors.grey.shade400, size: 22),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Batches List View ─────────────────────────────────────────────

  Widget _buildBatchesList(bool isDark, Color bg) {
    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _autoRefresh?.cancel();
          setState(() {
            _site = null;
            _batches = [];
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
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: isDark ? Colors.white : const Color(0xFF1A1D21)),
                        onPressed: () {
                          if (widget.site != null) {
                            Navigator.of(context).pop();
                          } else {
                            _autoRefresh?.cancel();
                            setState(() {
                              _site = null;
                              _batches = [];
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lots de Tickets',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1A1D21),
                                )),
                            Text(_site!.nom,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade500,
                                )),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _load,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.refresh,
                              size: 20,
                              color: isDark ? Colors.white70 : Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

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
                      controller: _searchController,
                      onChanged: (v) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () {
                          setState(() => _search = v);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Rechercher un lot...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 18, right: 8),
                          child: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 22),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: _search.isNotEmpty
                            ? Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: IconButton(
                                  icon: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 20),
                                  onPressed: () { _searchController.clear(); setState(() => _search = ''); },
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

                const SizedBox(height: 8),

                // Error banner
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12))),
                        ],
                      ),
                    ),
                  ),

                // Count row
                if (!_loading && _filteredBatches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Text('${_filteredBatches.length} lot${_filteredBatches.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),

                // Content
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredBatches.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.35,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.confirmation_number_outlined,
                                            size: 48, color: Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        Text(
                                            _search.isNotEmpty ? 'Aucun resultat' : 'Aucun lot genere',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
                                            )),
                                        const SizedBox(height: 6),
                                        Text(
                                            _search.isNotEmpty ? 'Essayez un autre terme.' : 'Appuyez sur "Generer" pour creer des tickets',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade400,
                                            )),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: _filteredBatches.length,
                              itemBuilder: (ctx, i) => _buildBatchCard(_filteredBatches[i], isDark),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Batch Card ────────────────────────────────────────────────────

  Widget _buildBatchCard(Map<String, dynamic> b, bool isDark) {
    final quantity = b['quantity'] ?? b['quantity_generated'] ?? b['count'] ?? 0;
    final available = b['available_count'] ?? 0;
    final used = b['used_count'] ?? 0;
    final pointName = b['point_name'];

    // Status based on available/used ratio
    final Color statusColor;
    final String statusLabel;
    if (available == 0 && used > 0) {
      statusColor = Colors.grey;
      statusLabel = 'Epuise';
    } else if (available > 0 && used > 0) {
      statusColor = AppTheme.warning;
      statusLabel = '$available dispo';
    } else {
      statusColor = AppTheme.success;
      statusLabel = '$available dispo';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _showBatchDetail(b),
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ticket icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.confirmation_number,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),

            // Profile name x quantity + date + point
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b['profile_name'] ?? b['profile'] ?? '-'} x$quantity',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        b['created_fmt'] ?? b['created_at'] ?? b['date'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      if (pointName != null) ...[
                        Text(' | ', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                        Icon(Icons.store, size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(pointName.toString(),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Batch Detail Bottom Sheet ──────────────────────────────────

  void _showBatchDetail(Map<String, dynamic> batch) async {
    final batchId = batch['batch_id']?.toString();
    if (batchId == null || _site == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BatchDetailSheet(
          siteId: _site!.id,
          batchId: batchId,
          batch: batch,
          isDark: isDark,
          service: _service,
        );
      },
    );
  }
}

// ── Batch Detail Sheet (stateful for loading) ───────────────────

class _BatchDetailSheet extends StatefulWidget {
  final int siteId;
  final String batchId;
  final Map<String, dynamic> batch;
  final bool isDark;
  final TicketService service;

  const _BatchDetailSheet({
    required this.siteId,
    required this.batchId,
    required this.batch,
    required this.isDark,
    required this.service,
  });

  @override
  State<_BatchDetailSheet> createState() => _BatchDetailSheetState();
}

class _BatchDetailSheetState extends State<_BatchDetailSheet> {
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.service.fetchBatchDetail(widget.siteId, widget.batchId);
      if (data['success'] == true) {
        _tickets = (data['tickets'] as List? ?? []).cast<Map<String, dynamic>>();
      } else {
        _error = data['error']?.toString() ?? 'Erreur inconnue';
      }
    } catch (e) {
      _error = 'Erreur: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _copyAllTickets() {
    if (_tickets.isEmpty) return;
    final buffer = StringBuffer();
    buffer.writeln('Lot: ${widget.batch['profile_name'] ?? '-'} x${widget.batch['quantity'] ?? _tickets.length}');
    buffer.writeln('Date: ${widget.batch['created_fmt'] ?? widget.batch['created_at'] ?? ''}');
    buffer.writeln('---');
    for (final t in _tickets) {
      final code = t['code'] ?? t['username'] ?? '-';
      final pass = t['password'] ?? '-';
      final status = t['status'] ?? '';
      buffer.writeln('Code: $code  |  Mot de passe: $pass  |  $status');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tickets copies dans le presse-papiers'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _copyTicket(Map<String, dynamic> t) {
    final code = t['code'] ?? t['username'] ?? '-';
    final pass = t['password'] ?? '-';
    Clipboard.setData(ClipboardData(text: 'Code: $code  Mot de passe: $pass'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ticket $code copie'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final profileName = widget.batch['profile_name'] ?? widget.batch['profile'] ?? '-';
    final quantity = widget.batch['quantity'] ?? widget.batch['count'] ?? 0;
    final available = widget.batch['available_count'] ?? 0;
    final used = widget.batch['used_count'] ?? 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.confirmation_number, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$profileName x$quantity',
                        style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF1A1D21),
                        )),
                      const SizedBox(height: 2),
                      Text(
                        '$available dispo  ·  $used utilise${used > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                // Copy all button
                GestureDetector(
                  onTap: _tickets.isNotEmpty ? _copyAllTickets : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.copy_all,
                        size: 20,
                        color: _tickets.isNotEmpty
                            ? (isDark ? Colors.white70 : Colors.grey.shade600)
                            : Colors.grey.shade300),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Divider
          Divider(height: 1, color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),

          // Content
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12))),
                ]),
              ),
            )
          else if (_tickets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Text('Aucun ticket dans ce lot',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) => _buildTicketRow(_tickets[i], i + 1, isDark),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketRow(Map<String, dynamic> t, int index, bool isDark) {
    final code = t['code'] ?? t['username'] ?? '-';
    final password = t['password'] ?? '-';
    final status = t['status'] ?? 'available';
    final isUsed = status == 'used';

    final Color statusColor = isUsed ? Colors.grey : AppTheme.success;
    final String statusLabel = isUsed ? 'Utilise' : 'Dispo';

    return GestureDetector(
      onTap: () => _copyTicket(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBg : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(12),
          border: isUsed
              ? Border.all(color: Colors.grey.shade300.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            // Index
            SizedBox(
              width: 28,
              child: Text('#$index',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: Colors.grey.shade400,
                  )),
            ),

            // Code + password
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code,
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: isUsed
                            ? Colors.grey.shade400
                            : (isDark ? Colors.white : const Color(0xFF1A1D21)),
                        decoration: isUsed ? TextDecoration.lineThrough : null,
                      )),
                  const SizedBox(height: 2),
                  Text('mdp: $password',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey.shade500,
                      )),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  )),
            ),

            const SizedBox(width: 6),

            // Copy icon
            Icon(Icons.copy, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
