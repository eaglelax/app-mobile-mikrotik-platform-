import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';

class FlashSaleScreen extends StatefulWidget {
  final Site site;
  const FlashSaleScreen({super.key, required this.site});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _points = [];
  int? _selectedPointId;
  bool _loading = true;
  bool _selling = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    try {
      final api = ApiClient();
      final data = await api.get('/api/flash-sale.php', {'site_id': widget.site.id.toString()});
      if (data['success'] == true) {
        final profiles = data['profiles'] as List? ?? [];
        _profiles = profiles.cast<Map<String, dynamic>>();
        final pts = data['points'] as List? ?? [];
        _points = pts.cast<Map<String, dynamic>>();
        if (_points.isNotEmpty) {
          _selectedPointId = _points.first['id'] is int
              ? _points.first['id'] as int
              : int.tryParse(_points.first['id'].toString());
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sell(String profileName) async {
    if (_selling) return;
    setState(() {
      _selling = true;
      _result = null;
    });

    try {
      final api = ApiClient();
      final data = await api.post('/api/flash-sale.php', {
        'site_id': widget.site.id,
        'profile': profileName,
        if (_selectedPointId != null) 'point_id': _selectedPointId,
      });
      if (data['success'] == true) {
        setState(() => _result = data);
      } else {
        _showError(data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      _showError(e.toString());
    }

    if (mounted) setState(() => _selling = false);
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.danger),
      );
    }
  }

  void _newSale() => setState(() => _result = null);

  void _copyCode() {
    if (_result == null) return;
    final text =
        'Code: ${_result!['code']}\nMot de passe: ${_result!['password']}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copié !'), duration: Duration(seconds: 1)),
    );
  }

  // --- Color palette icons for profile cards ---
  static const List<Color> _cardColors = [
    Color(0xFF6366F1), // indigo
    Color(0xFF8B5CF6), // violet
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
    Color(0xFF3B82F6), // blue
    Color(0xFF10B981), // emerald
    Color(0xFFEF4444), // red
  ];

  static const List<IconData> _cardIcons = [
    Icons.wifi_rounded,
    Icons.bolt_rounded,
    Icons.rocket_launch_rounded,
    Icons.speed_rounded,
    Icons.cloud_rounded,
    Icons.signal_wifi_4_bar_rounded,
    Icons.flash_on_rounded,
    Icons.star_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: textColor,
                    ),
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vente Flash',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          widget.site.nom,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Flash icon badge
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.accent,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Body content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                        strokeWidth: 3,
                      ),
                    )
                  : _result != null
                      ? _buildResult(isDark, textColor, subtitleColor)
                      : _selling
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                      color: AppTheme.accent,
                                      strokeWidth: 3,
                                    ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Génération en cours...',
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildProfileGrid(isDark, textColor, subtitleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileGrid(bool isDark, Color textColor, Color subtitleColor) {
    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: subtitleColor.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Aucun profil disponible',
              style: TextStyle(color: subtitleColor, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    return Column(
      children: [
        if (_points.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: DropdownButtonFormField<int>(
                initialValue: _selectedPointId,
                decoration: InputDecoration(
                  labelText: 'Point de vente',
                  prefixIcon: Icon(Icons.storefront_rounded,
                      color: AppTheme.primary.withValues(alpha: 0.7)),
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  labelStyle: TextStyle(color: subtitleColor),
                ),
                dropdownColor: cardBg,
                style: TextStyle(color: textColor, fontSize: 14),
                items: _points.map((p) {
                  final id = p['id'] is int
                      ? p['id'] as int
                      : int.tryParse(p['id'].toString()) ?? 0;
                  return DropdownMenuItem(value: id, child: Text(p['name'] ?? ''));
                }).toList(),
                onChanged: (v) => setState(() => _selectedPointId = v),
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: _profiles.length,
            itemBuilder: (ctx, i) {
              final p = _profiles[i];
              final name = p['name'] ?? '';
              final price = p['price'] ?? p['ticket_price'];
              final duration = p['duration'] ?? p['limit_uptime'] ?? '';
              final currency = p['currency'] ?? 'FCFA';

              final accentColor = _cardColors[i % _cardColors.length];
              final icon = _cardIcons[i % _cardIcons.length];

              return GestureDetector(
                onTap: () => _sell(name),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Colored icon container
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: accentColor, size: 26),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: textColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (duration.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            duration.toString(),
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        if (price != null && price != 0)
                          Text(
                            '${Fmt.number(price)} $currency',
                            style: const TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          )
                        else
                          Text(
                            'Prix non défini',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Vendre',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResult(bool isDark, Color textColor, Color subtitleColor) {
    final code = _result!['code'] ?? '';
    final password = _result!['password'] ?? '';
    final profile = _result!['profile'] ?? '';
    final price = _result!['price'];
    final duration = _result!['duration'] ?? '';
    final autologinUrl = _result!['autologin_url'];
    final qrData = autologinUrl ?? code;

    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);
    final footerBg = isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA);
    final credValueColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Ticket card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_rounded,
                          color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        widget.site.nom,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // QR Code with rounded container
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 170,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Credentials in rounded containers
                      _buildCredRow('Code', code, isDark, credValueColor,
                          subtitleColor, borderColor),
                      const SizedBox(height: 8),
                      _buildCredRow('Mot de passe', password, isDark,
                          credValueColor, subtitleColor, borderColor),

                      const SizedBox(height: 16),

                      // Info pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          _Pill(profile, AppTheme.primary, isDark),
                          if (price != null && price != 0)
                            _Pill(
                              '${Fmt.number(price)} ${_result!['currency'] ?? 'FCFA'}',
                              AppTheme.success,
                              isDark,
                            ),
                          if (duration.toString().isNotEmpty)
                            _Pill(duration.toString(), AppTheme.accent, isDark),
                        ],
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: footerBg,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: subtitleColor),
                      const SizedBox(width: 6),
                      Text(
                        'Connectez-vous au WiFi puis scannez le QR code',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _copyCode,
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.darkSurface : Colors.grey.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _newSale,
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Nouvelle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCredRow(String label, String value, bool isDark,
      Color valueColor, Color labelColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurface.withValues(alpha: 0.5)
            : const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 2,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;
  const _Pill(this.label, this.color, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? color.withValues(alpha: 0.9) : color,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
