import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/formatters.dart';

class FlashSaleScreen extends StatefulWidget {
  final Site site;
  const FlashSaleScreen({super.key, required this.site});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _profiles = [];
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
      final data = await _service.fetchProfiles(widget.site.id);
      final profiles = data['profiles'] as List? ?? [];
      _profiles = profiles.cast<Map<String, dynamic>>();
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
      final data = await _service.flashSale(widget.site.id, profileName);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vente Flash'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _result != null
              ? _buildResult()
              : _selling
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.accent),
                          SizedBox(height: 16),
                          Text('Génération en cours...'),
                        ],
                      ),
                    )
                  : _buildProfileGrid(),
    );
  }

  Widget _buildProfileGrid() {
    if (_profiles.isEmpty) {
      return const Center(child: Text('Aucun profil disponible'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _profiles.length,
      itemBuilder: (ctx, i) {
        final p = _profiles[i];
        final name = p['name'] ?? '';
        final price = p['price'] ?? p['ticket_price'];
        final duration = p['duration'] ?? p['limit_uptime'] ?? '';
        final currency = p['currency'] ?? 'FCFA';

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _sell(name),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi,
                        color: AppTheme.accent, size: 24),
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (duration.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(duration.toString(),
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                  ],
                  const SizedBox(height: 6),
                  if (price != null && price != 0)
                    Text('${Fmt.number(price)} $currency',
                        style: const TextStyle(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w800,
                            fontSize: 16))
                  else
                    Text('Prix non défini',
                        style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Vendre',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult() {
    final code = _result!['code'] ?? '';
    final password = _result!['password'] ?? '';
    final profile = _result!['profile'] ?? '';
    final price = _result!['price'];
    final duration = _result!['duration'] ?? '';
    final autologinUrl = _result!['autologin_url'];
    final qrData = autologinUrl ?? code;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Ticket card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: const BoxDecoration(
                    color: Color(0xFF23272B),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi, color: AppTheme.info, size: 20),
                      const SizedBox(width: 8),
                      Text(widget.site.nom,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // QR Code
                      QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 180,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),

                      // Credentials
                      _CredRow('Code', code),
                      _CredRow('Mot de passe', password),

                      const SizedBox(height: 12),

                      // Info pills
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: [
                          _Pill(profile, AppTheme.primary),
                          if (price != null && price != 0)
                            _Pill(
                                '${Fmt.number(price)} ${_result!['currency'] ?? 'FCFA'}',
                                AppTheme.success),
                          if (duration.toString().isNotEmpty)
                            _Pill(duration.toString(), AppTheme.accent),
                        ],
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(14)),
                  ),
                  child: const Text(
                    'Connectez-vous au WiFi puis scannez le QR code',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
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
                child: ElevatedButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copier'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _newSale,
                  icon: const Icon(Icons.bolt, size: 18),
                  label: const Text('Nouvelle'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CredRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF1A1D21),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 2,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style:
              TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
