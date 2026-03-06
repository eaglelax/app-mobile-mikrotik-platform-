import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../models/site.dart';
import '../../services/point_service_api.dart';
import '../../widgets/site_selector.dart';

class PointsListScreen extends StatefulWidget {
  final Site? site;
  const PointsListScreen({super.key, this.site});

  @override
  State<PointsListScreen> createState() => _PointsListScreenState();
}

class _PointsListScreenState extends State<PointsListScreen> {
  final _service = PointServiceApi();
  Site? _site;
  List<Point> _points = [];
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
      _points = await _service.fetchBySite(_site!.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_site == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Points de Vente')),
        body: SiteSelector(
          onSelect: (s) {
            setState(() => _site = s);
            _load();
          },
        ),
      );
    }

    return PopScope(
      canPop: widget.site != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() { _site = null; _points = []; });
      },
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Points de Vente'),
            Text(_site!.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to add point form
        },
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _points.isEmpty
              ? const Center(child: Text('Aucun point de vente'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _points.length,
                    itemBuilder: (ctx, i) {
                      final p = _points[i];
                      final typeIcons = {
                        'vendeur': Icons.store,
                        'zone': Icons.place,
                        'partenaire': Icons.handshake,
                        'lieu': Icons.location_on,
                      };
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            typeIcons[p.type] ?? Icons.store,
                            color: p.isActive ? AppTheme.primary : Colors.grey,
                          ),
                          title: Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Type: ${p.type}',
                                  style: const TextStyle(fontSize: 12)),
                              if (p.contactName != null)
                                Text('Contact: ${p.contactName}',
                                    style: const TextStyle(fontSize: 12)),
                              if (p.serverName != null)
                                Text('Serveur: ${p.serverName}',
                                    style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (p.isActive
                                      ? AppTheme.success
                                      : Colors.grey)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              p.isActive ? 'Actif' : 'Inactif',
                              style: TextStyle(
                                  color: p.isActive
                                      ? AppTheme.success
                                      : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    ),
    );
  }
}
