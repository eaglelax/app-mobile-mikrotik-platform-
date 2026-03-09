import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/ticket_service.dart';

class TicketBatchesScreen extends StatefulWidget {
  final Site? site;
  const TicketBatchesScreen({super.key, this.site});

  @override
  State<TicketBatchesScreen> createState() => _TicketBatchesScreenState();
}

class _TicketBatchesScreenState extends State<TicketBatchesScreen> {
  final _service = TicketService();
  Site? _site;
  List<Map<String, dynamic>> _batches = [];
  bool _loading = false;
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
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefresh?.cancel();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() => _loading = true);
    try {
      final data = await _service.fetchBatches(_site!.id);
      final inner = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
      _batches =
          (inner['batches'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: sites.length,
                              itemBuilder: (ctx, i) {
                                final site = sites[i];
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

                // Count row
                if (!_loading && _batches.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Text('${_batches.length} lot${_batches.length > 1 ? 's' : ''}',
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
                      : _batches.isEmpty
                          ? ListView(
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.confirmation_number_outlined,
                                            size: 48, color: Colors.grey.shade300),
                                        const SizedBox(height: 12),
                                        Text('Aucun lot',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Colors.grey.shade400,
                                              fontWeight: FontWeight.w500,
                                            )),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              itemCount: _batches.length,
                              itemBuilder: (ctx, i) => _buildBatchCard(_batches[i], isDark),
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
    final status = b['status'] ?? 'completed';
    final statusColor = status == 'pending'
        ? AppTheme.warning
        : status == 'failed'
            ? AppTheme.danger
            : AppTheme.success;

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
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.confirmation_number,
                  color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),

            // Profile name x quantity + date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${b['profile_name'] ?? b['profile'] ?? '-'} x${b['quantity_generated'] ?? b['quantity'] ?? b['count'] ?? '?'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    b['created_at'] ?? b['date'] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
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
              child: Text(status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
