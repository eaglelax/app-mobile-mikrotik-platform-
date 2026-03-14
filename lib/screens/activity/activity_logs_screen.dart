import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';

class ActivityLogsScreen extends StatefulWidget {
  final int? siteId;
  final String? siteName;

  const ActivityLogsScreen({super.key, this.siteId, this.siteName});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  int _page = 1;
  int _totalPages = 1;
  String? _actionFilter;

  static const _actionLabels = {
    'generate_tickets': 'Generation tickets',
    'flash_sale': 'Vente flash',
    'sell_ticket': 'Vente ticket',
    'remove_user': 'Suppression ticket',
    'remove_all_tickets': 'Suppression tous tickets',
    'delete_db_tickets': 'Suppression tickets DB',
    'delete_batch': 'Suppression lot',
    'cancel_batch': 'Annulation lot',
    'mark_printed': 'Impression',
    'add_user': 'Ajout utilisateur',
    'disconnect_user': 'Deconnexion',
    'clear_mac': 'Reset MAC',
    'sync_tickets_to_db': 'Sync tickets',
    'sync_vps': 'Sync VPS',
    'deploy_full': 'Deploiement complet',
    'deploy_local': 'Deploiement local',
    'deploy_vpn_only': 'Config VPN',
    'reboot_router': 'Redemarrage routeur',
    'shutdown_router': 'Arret routeur',
    'create_site': 'Creation site',
    'update_site': 'Modification site',
    'delete_site': 'Suppression site',
    'create_point': 'Creation point',
    'update_point': 'Modification point',
    'delete_point': 'Suppression point',
    'login': 'Connexion',
    'logout': 'Deconnexion',
  };

  static const _actionIcons = {
    'generate_tickets': Icons.confirmation_number,
    'flash_sale': Icons.flash_on,
    'sell_ticket': Icons.point_of_sale,
    'remove_user': Icons.person_remove,
    'remove_all_tickets': Icons.delete_sweep,
    'delete_db_tickets': Icons.storage,
    'delete_batch': Icons.delete,
    'cancel_batch': Icons.cancel,
    'mark_printed': Icons.print,
    'add_user': Icons.person_add,
    'disconnect_user': Icons.wifi_off,
    'clear_mac': Icons.phonelink_erase,
    'sync_tickets_to_db': Icons.sync,
    'sync_vps': Icons.cloud_sync,
    'deploy_full': Icons.rocket_launch,
    'deploy_local': Icons.upload,
    'deploy_vpn_only': Icons.vpn_key,
    'reboot_router': Icons.restart_alt,
    'shutdown_router': Icons.power_settings_new,
    'login': Icons.login,
    'logout': Icons.logout,
  };

  static Color _actionColor(String action) {
    if (action.contains('delete') || action.contains('remove') || action == 'shutdown_router') {
      return Colors.red;
    }
    if (action.contains('generate') || action.contains('create') || action == 'add_user') {
      return Colors.green;
    }
    if (action.contains('sell') || action == 'flash_sale') {
      return Colors.blue;
    }
    if (action.contains('sync') || action.contains('deploy')) {
      return Colors.orange;
    }
    if (action == 'cancel_batch') return Colors.amber.shade700;
    if (action == 'reboot_router') return Colors.deepOrange;
    if (action == 'clear_mac' || action == 'disconnect_user') return Colors.purple;
    return Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    try {
      final params = <String, String>{
        'page': _page.toString(),
        'per_page': '30',
      };
      if (widget.siteId != null) {
        params['site_id'] = widget.siteId.toString();
      }
      if (_actionFilter != null) {
        params['action'] = _actionFilter!;
      }

      final result = await _api.get('/api/activity-logs.php', params);
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(result['logs'] ?? []);
          _totalPages = (result['pages'] as int?) ?? 1;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.siteName != null ? 'Historique - ${widget.siteName}' : 'Historique'),
        actions: [
          PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_list,
              color: _actionFilter != null ? AppTheme.primary : null,
            ),
            tooltip: 'Filtrer',
            onSelected: (value) {
              _actionFilter = value;
              _page = 1;
              _fetchLogs();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Toutes les actions')),
              const PopupMenuDivider(),
              ..._actionLabels.entries.map((e) => PopupMenuItem(
                value: e.key,
                child: Row(
                  children: [
                    Icon(_actionIcons[e.key] ?? Icons.circle, size: 18, color: _actionColor(e.key)),
                    const SizedBox(width: 8),
                    Text(e.value),
                  ],
                ),
              )),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Aucune activite',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _logs.length + (_totalPages > 1 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _logs.length) {
                        return _buildPagination();
                      }
                      return _buildLogTile(_logs[index], isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log, bool isDark) {
    final action = log['action'] ?? '';
    final label = _actionLabels[action] ?? action;
    final icon = _actionIcons[action] ?? Icons.circle;
    final color = _actionColor(action);
    final details = log['details'] ?? '';
    final userName = log['user_name'] ?? log['user_email'] ?? 'Systeme';
    final timeFmt = log['created_relative'] ?? log['created_fmt'] ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  details,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    userName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                const SizedBox(width: 3),
                Text(
                  timeFmt,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: details.isNotEmpty,
      ),
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    _page--;
                    _fetchLogs();
                  }
                : null,
          ),
          Text('$_page / $_totalPages', style: const TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < _totalPages
                ? () {
                    _page++;
                    _fetchLogs();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
