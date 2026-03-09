import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/formatters.dart';

class HotspotActiveScreen extends StatefulWidget {
  final Site site;
  const HotspotActiveScreen({super.key, required this.site});

  @override
  State<HotspotActiveScreen> createState() => _HotspotActiveScreenState();
}

class _HotspotActiveScreenState extends State<HotspotActiveScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _active = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchActiveUsers(widget.site.id);
      _active = (data['active'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade500;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // -- Custom Header --
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Connexions Actives',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_active.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          size: 20, color: subtextColor),
                    ),
                  ),
                ],
              ),
            ),

            // -- Content --
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : _active.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wifi_off_rounded,
                                  size: 48, color: subtextColor),
                              const SizedBox(height: 12),
                              Text(
                                'Aucune connexion active',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: subtextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: _active.length,
                            itemBuilder: (ctx, i) {
                              final a = _active[i];
                              return _buildActiveItem(
                                a,
                                cardColor: cardColor,
                                textColor: textColor,
                                subtextColor: subtextColor,
                                borderColor: borderColor,
                                isDark: isDark,
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

  Widget _buildActiveItem(
    Map<String, dynamic> a, {
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.wifi_tethering,
                color: AppTheme.success, size: 20),
          ),
          const SizedBox(width: 12),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a['user'] ?? a['name'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IP: ${a['address'] ?? '-'}  Uptime: ${a['uptime'] ?? '-'}',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
              ],
            ),
          ),

          // Traffic
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (a['bytes-in'] != null)
                Text(
                  '\u2193 ${Fmt.bytes(int.tryParse(a['bytes-in'].toString()) ?? 0)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.primary),
                ),
              if (a['bytes-out'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '\u2191 ${Fmt.bytes(int.tryParse(a['bytes-out'].toString()) ?? 0)}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.accent),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
