import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../widgets/site_selector.dart';

class VouchersScreen extends StatefulWidget {
  final Site? site;
  const VouchersScreen({super.key, this.site});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  final _service = MikhmonService();
  Site? _site;
  List<Map<String, dynamic>> _vouchers = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = false;
  String? _profileFilter;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _site = widget.site;
    if (_site != null) _load();
  }

  Future<void> _load() async {
    if (_site == null) return;
    setState(() => _loading = true);
    try {
      final data = await _service.fetchHotspotUsers(_site!.id);
      _vouchers =
          (data['users'] as List? ?? []).cast<Map<String, dynamic>>();
      _applyFilters();
    } catch (_) {}
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

  Set<String> get _profiles =>
      _vouchers.map((v) => (v['profile'] ?? '').toString()).toSet();

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vouchers')),
        body: SiteSelector(onSelect: (s) {
          setState(() => _site = s);
          _load();
        }),
      );
    }

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() { _site = null; _vouchers = []; _filtered = []; });
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vouchers (${_filtered.length})'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) {
                setState(() {
                  _search = v;
                  _applyFilters();
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Tous'),
                    selected: _profileFilter == null,
                    onSelected: (_) {
                      setState(() {
                        _profileFilter = null;
                        _applyFilters();
                      });
                    },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                ..._profiles.map((p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(p),
                        selected: _profileFilter == p,
                        onSelected: (_) {
                          setState(() {
                            _profileFilter = p;
                            _applyFilters();
                          });
                        },
                        selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('Aucun voucher'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final v = _filtered[i];
                            final disabled = v['disabled'] == 'true' ||
                                v['disabled'] == true;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: ListTile(
                                leading: Icon(
                                  Icons.confirmation_number,
                                  color: disabled
                                      ? Colors.grey
                                      : AppTheme.success,
                                  size: 22,
                                ),
                                title: Text(v['name'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        letterSpacing: 1.2)),
                                subtitle: Text(
                                    'Profil: ${v['profile'] ?? '-'}  '
                                    '${v['limit-uptime'] ?? ''}',
                                    style: const TextStyle(fontSize: 12)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (disabled
                                            ? Colors.grey
                                            : AppTheme.success)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    disabled ? 'Utilisé' : 'Disponible',
                                    style: TextStyle(
                                        color: disabled
                                            ? Colors.grey
                                            : AppTheme.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                dense: true,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    ),
    );
  }
}
