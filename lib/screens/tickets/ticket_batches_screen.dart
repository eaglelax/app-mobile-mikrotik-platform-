import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/ticket_service.dart';
import '../../widgets/site_selector.dart';

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
      final data = await _service.fetchBatches(_site!.id);
      _batches =
          (data['batches'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lots de tickets')),
        body: SiteSelector(onSelect: (s) {
          setState(() => _site = s);
          _load();
        }),
      );
    }

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() { _site = null; _batches = []; });
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lots de tickets'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
              ? const Center(child: Text('Aucun lot'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _batches.length,
                    itemBuilder: (ctx, i) {
                      final b = _batches[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.confirmation_number,
                                color: AppTheme.primary, size: 22),
                          ),
                          title: Text(
                              '${b['profile_name'] ?? b['profile'] ?? '-'} x${b['quantity'] ?? b['count'] ?? '?'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              b['created_at'] ?? b['date'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500)),
                          trailing: _batchStatus(b),
                          isThreeLine: false,
                        ),
                      );
                    },
                  ),
                ),
    ),
    );
  }

  Widget _batchStatus(Map<String, dynamic> b) {
    final status = b['status'] ?? 'completed';
    final color = status == 'pending'
        ? AppTheme.warning
        : status == 'failed'
            ? AppTheme.danger
            : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(status,
          style:
              TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
