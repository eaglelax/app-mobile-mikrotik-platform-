import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../models/site.dart';
import '../../services/point_service_api.dart';
import '../../widgets/site_selector.dart';
import 'gerants_screen.dart';
import 'point_form_screen.dart';

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

  Future<void> _deletePoint(Point point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le point'),
        content: Text('Supprimer "${point.name}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await _service.delete(point.id);
      if (result['success'] == true) {
        _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Erreur'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
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
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PointFormScreen(siteId: _site!.id),
            ),
          );
          if (created == true) _load();
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
                          onLongPress: () => _deletePoint(p),
                          onTap: () async {
                            final edited = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PointFormScreen(
                                  siteId: _site!.id, point: p,
                                ),
                              ),
                            );
                            if (edited == true) _load();
                          },
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
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
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
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.person,
                                    size: 20, color: AppTheme.accent),
                                tooltip: 'Gerants',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GerantsScreen(point: p),
                                    ),
                                  );
                                },
                              ),
                            ],
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
