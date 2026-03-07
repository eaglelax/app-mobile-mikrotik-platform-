import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class LogsScreen extends StatefulWidget {
  final Site site;
  final String initialTopic;
  const LogsScreen({super.key, required this.site, this.initialTopic = 'hotspot'});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  late String _topic;

  final _topics = const {
    'hotspot': 'Hotspot',
    'system': 'Système',
    'error': 'Erreurs',
    'warning': 'Alertes',
    'info': 'Info',
  };

  @override
  void initState() {
    super.initState();
    _topic = widget.initialTopic;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchLogs(widget.site.id, topic: _topic);
      _logs = (data['logs'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Logs'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: _topics.entries.map((e) {
                final selected = e.key == _topic;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _topic = e.key);
                      _load();
                    },
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(child: Text('Aucun log'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _logs.length,
                          itemBuilder: (ctx, i) {
                            final log = _logs[i];
                            final time = log['time'] ?? '';
                            final message = log['message'] ?? '';
                            final topics = log['topics'] ?? '';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 4),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_topicIcon(topics),
                                            size: 14,
                                            color: _topicColor(topics)),
                                        const SizedBox(width: 6),
                                        Text(time,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                                fontFamily: 'monospace')),
                                        const Spacer(),
                                        Text(topics,
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(message,
                                        style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  IconData _topicIcon(String topics) {
    if (topics.contains('error')) return Icons.error_outline;
    if (topics.contains('warning')) return Icons.warning_amber;
    if (topics.contains('hotspot')) return Icons.wifi;
    return Icons.info_outline;
  }

  Color _topicColor(String topics) {
    if (topics.contains('error')) return AppTheme.danger;
    if (topics.contains('warning')) return AppTheme.warning;
    if (topics.contains('hotspot')) return AppTheme.primary;
    return Colors.grey;
  }
}
