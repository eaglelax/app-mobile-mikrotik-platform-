import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/formatters.dart';

class TrafficScreen extends StatefulWidget {
  final Site site;
  const TrafficScreen({super.key, required this.site});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  final _service = MikhmonService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await _service.fetchTraffic(widget.site.id);
      _data = raw['data'] is Map<String, dynamic>
          ? raw['data'] as Map<String, dynamic>
          : raw;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trafic')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.bar_chart,
                              size: 48, color: AppTheme.primary),
                          const SizedBox(height: 12),
                          Text('Trafic - ${widget.site.nom}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 16),
                          _TrafficRow(
                              'Download',
                              Fmt.bytes(
                                  _data?['rx'] ?? _data?['rx_bytes'] ?? 0),
                              AppTheme.primary),
                          _TrafficRow(
                              'Upload',
                              Fmt.bytes(
                                  _data?['tx'] ?? _data?['tx_bytes'] ?? 0),
                              AppTheme.accent),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TrafficRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TrafficRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(label == 'Download' ? Icons.arrow_downward : Icons.arrow_upward,
              color: color, size: 20),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 14)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
