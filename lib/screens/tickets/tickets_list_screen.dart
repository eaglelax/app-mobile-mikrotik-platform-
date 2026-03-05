import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/ticket_service.dart';
import '../../utils/constants.dart';
import '../../widgets/site_selector.dart';
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
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = false;
  String? _statusFilter;

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
      final data = await _service.fetchTickets(_site!.id, status: _statusFilter);
      _tickets =
          (data['vouchers'] ?? data['tickets'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tickets')),
        body: SiteSelector(
          onSelect: (s) {
            setState(() => _site = s);
            _load();
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tickets'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
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
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                for (final f in [
                  (null, 'Tous'),
                  ('available', 'Disponibles'),
                  ('used', 'Utilisés'),
                  ('expired', 'Expirés'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: _statusFilter == f.$1,
                      onSelected: (_) {
                        setState(() => _statusFilter = f.$1);
                        _load();
                      },
                      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tickets.isEmpty
                    ? const Center(child: Text('Aucun ticket'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _tickets.length,
                        itemBuilder: (ctx, i) {
                          final t = _tickets[i];
                          final status = t['status'] ?? 'available';
                          final statusColor = switch (status) {
                            'available' => AppTheme.success,
                            'used' => AppTheme.primary,
                            'expired' => AppTheme.danger,
                            _ => Colors.grey,
                          };
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              leading: Icon(Icons.confirmation_number,
                                  color: statusColor, size: 22),
                              title: Text(t['code'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                      letterSpacing: 1.5)),
                              subtitle: Text(
                                  '${t['profile'] ?? t['profile_name'] ?? '-'}  ${t['limit_uptime'] ?? ''}',
                                  style: const TextStyle(fontSize: 12)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  AppConstants.ticketStatuses[status] ?? status,
                                  style: TextStyle(
                                      color: statusColor,
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
        ],
      ),
    );
  }
}
