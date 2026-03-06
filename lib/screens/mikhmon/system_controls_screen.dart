import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class SystemControlsScreen extends StatefulWidget {
  final Site site;
  const SystemControlsScreen({super.key, required this.site});

  @override
  State<SystemControlsScreen> createState() => _SystemControlsScreenState();
}

class _SystemControlsScreenState extends State<SystemControlsScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _schedulers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedulers();
  }

  Future<void> _loadSchedulers() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchSchedulers(widget.site.id);
      _schedulers =
          (data['schedulers'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirmAction(String action, String title, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      Map<String, dynamic> result;
      if (action == 'reboot') {
        result = await _service.rebootRouter(widget.site.id);
      } else {
        result = await _service.shutdownRouter(widget.site.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'Action effectuée'),
              backgroundColor: AppTheme.success),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Système'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Actions système',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          Card(
            child: ListTile(
              leading: const Icon(Icons.restart_alt, color: AppTheme.warning),
              title: const Text('Redémarrer le routeur',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Les utilisateurs actifs seront déconnectés',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmAction(
                'reboot',
                'Redémarrer le routeur ?',
                'Le routeur ${widget.site.nom} sera redémarré. Tous les utilisateurs actifs seront déconnectés.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.power_settings_new,
                  color: AppTheme.danger),
              title: const Text('Éteindre le routeur',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppTheme.danger)),
              subtitle: const Text(
                  'Le routeur devra être rallumé manuellement',
                  style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _confirmAction(
                'shutdown',
                'Éteindre le routeur ?',
                'Le routeur ${widget.site.nom} sera arrêté. Il faudra le rallumer physiquement.',
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Text('Planificateur (Scheduler)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_schedulers.isEmpty)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucune tâche planifiée',
                  style: TextStyle(color: Colors.grey)),
            ))
          else
            ..._schedulers.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      s['disabled'] == 'true'
                          ? Icons.pause_circle_outline
                          : Icons.schedule,
                      color: s['disabled'] == 'true'
                          ? Colors.grey
                          : AppTheme.primary,
                    ),
                    title: Text(s['name'] ?? '',
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Intervalle: ${s['interval'] ?? '-'}\n'
                      'Prochaine: ${s['next-run'] ?? '-'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    isThreeLine: true,
                    dense: true,
                  ),
                )),
        ],
      ),
    );
  }
}
