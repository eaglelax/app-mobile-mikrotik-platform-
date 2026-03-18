import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/ticket_service.dart';
import '../../utils/constants.dart';
import 'generate_tickets_screen.dart';

class TicketsListScreen extends StatefulWidget {
  final Site? site;
  const TicketsListScreen({super.key, this.site});

  @override
  State<TicketsListScreen> createState() => _TicketsListScreenState();
}

class _TicketsListScreenState extends State<TicketsListScreen> {
  final _service = TicketService();
  Site? _site;
  List<Map<String, dynamic>> _allTickets = [];
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = false;
  String? _statusFilter;
  String _search = '';
  final _searchController = TextEditingController();
  String _siteSearch = '';
  final _siteSearchController = TextEditingController();
  Timer? _debounce;
  Timer? _autoRefresh;

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

  String? _error;

  Future<void> _load() async {
    if (_site == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.fetchTickets(_site!.id);
      if (data['success'] == false) {
        _error = data['error']?.toString() ?? 'Erreur de chargement';
        _allTickets = [];
      } else {
        final list = data['vouchers'] ?? data['tickets'];
        _allTickets = (list is List ? list : []).cast<Map<String, dynamic>>();
        _error = null;
        // Avertissement si fallback DB
        if (data['warning'] != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['warning'].toString()),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      _applyFilter();
    } catch (e) {
      _error = 'Erreur réseau: $e';
      _allTickets = [];
      _applyFilter();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _cancelTicket(Map<String, dynamic> ticket) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Annuler ce ticket ?'),
        content: Text('Le ticket "${ticket['code']}" sera supprime du routeur.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Annuler le ticket'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.cancelTicket(_site!.id, ticket['.id'] ?? ticket['code'] ?? '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ticket annule'),
              backgroundColor: AppTheme.success),
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  void _applyFilter() {
    var filtered = _allTickets;
    if (_statusFilter != null) {
      filtered = filtered.where((t) => t['status'] == _statusFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((t) =>
          (t['code'] ?? '').toString().toLowerCase().contains(q) ||
          (t['profile'] ?? t['profile_name'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    _tickets = filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);

    if (_site == null) {
      return _buildSiteSelector(isDark, bg);
    }

    return _buildTicketsList(isDark, bg);
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
                          Text('Tickets',
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
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
                        : RefreshIndicator(
                            onRefresh: () => siteProv.fetchSites(),
                            child: Builder(
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
                            );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tickets List View ───────────────────────────────────────────────

  Widget _buildTicketsList(bool isDark, Color bg) {
    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _autoRefresh?.cancel();
          setState(() {
            _site = null;
            _allTickets = [];
            _tickets = [];
          });
        }
      },
      child: Scaffold(
        backgroundColor: bg,
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => GenerateTicketsScreen(site: _site!),
              ),
            );
            if (result == true) _load();
          },
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add, color: Colors.white),
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
                              _allTickets = [];
                              _tickets = [];
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tickets',
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

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildChip('Tous', _statusFilter == null, AppTheme.primary, isDark, () {
                        setState(() {
                          _statusFilter = null;
                          _applyFilter();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildChip('Disponibles', _statusFilter == 'available', AppTheme.success, isDark, () {
                        setState(() {
                          _statusFilter = 'available';
                          _applyFilter();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildChip('Utilises', _statusFilter == 'used', AppTheme.primary, isDark, () {
                        setState(() {
                          _statusFilter = 'used';
                          _applyFilter();
                        });
                      }),
                      const SizedBox(width: 8),
                      _buildChip('Expires', _statusFilter == 'expired', AppTheme.danger, isDark, () {
                        setState(() {
                          _statusFilter = 'expired';
                          _applyFilter();
                        });
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
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
                            setState(() { _search = v; _applyFilter(); });
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher un ticket...',
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
                                    onPressed: () { _searchController.clear(); setState(() { _search = ''; _applyFilter(); }); },
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
                ),

                const SizedBox(height: 8),

                // Count row
                if (!_loading && _tickets.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Text('${_tickets.length} ticket${_tickets.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            )),
                        const Spacer(),
                        Text('${_allTickets.length} au total',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            )),
                      ],
                    ),
                  ),

                // Content
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _tickets.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            _error != null
                                                ? Icons.wifi_off_rounded
                                                : Icons.confirmation_number_outlined,
                                            size: 48,
                                            color: _error != null
                                                ? AppTheme.danger.withValues(alpha: 0.5)
                                                : Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        Text(
                                            _error != null
                                                ? 'Erreur de connexion'
                                                : 'Aucun ticket',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: _error != null
                                                  ? AppTheme.danger
                                                  : Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
                                            )),
                                        if (_error != null) ...[
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 32),
                                            child: Text(_error!,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                )),
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            onPressed: _load,
                                            icon: const Icon(Icons.refresh, size: 18),
                                            label: const Text('Réessayer'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.primary,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: _tickets.length,
                              itemBuilder: (ctx, i) => _buildTicketCard(_tickets[i], isDark),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Custom Chip ─────────────────────────────────────────────────────

  Widget _buildChip(String label, bool selected, Color color, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? color : Colors.grey.shade500,
            )),
      ),
    );
  }

  num? _resolvePrice(dynamic val) {
    if (val == null) return null;
    final p = val is num ? val : num.tryParse(val.toString());
    if (p == null || p <= 0) return null;
    return p;
  }

  // ── Ticket Card ─────────────────────────────────────────────────────

  Widget _buildTicketCard(Map<String, dynamic> t, bool isDark) {
    final status = t['status'] ?? 'available';
    final statusColor = switch (status) {
      'available' => AppTheme.success,
      'used' => AppTheme.primary,
      'expired' => AppTheme.danger,
      _ => Colors.grey,
    };
    final statusLabel = AppConstants.ticketStatuses[status] ?? status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.confirmation_number, color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Code + profile info + price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t['code'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1A1D21),
                      )),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${t['profile'] ?? t['profile_name'] ?? '-'}  ${t['limit_uptime'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (_resolvePrice(t['price']) != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${_resolvePrice(t['price'])!.toStringAsFixed(0)}F',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.orange.shade300 : Colors.orange.shade700,
                          ),
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

            // PopupMenu for available tickets only
            if (status == 'available')
              PopupMenuButton(
                icon: Icon(Icons.more_vert,
                    size: 20,
                    color: isDark ? Colors.white54 : Colors.grey.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: isDark ? AppTheme.darkCard : Colors.white,
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Annuler',
                          style: TextStyle(color: AppTheme.danger))),
                ],
                onSelected: (action) {
                  if (action == 'cancel') {
                    _cancelTicket(t);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
