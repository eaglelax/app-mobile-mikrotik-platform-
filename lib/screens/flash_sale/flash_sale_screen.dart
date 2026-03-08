import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/api_client.dart';
import '../../utils/formatters.dart';

class FlashSaleScreen extends StatefulWidget {
  const FlashSaleScreen({super.key});

  @override
  State<FlashSaleScreen> createState() => _FlashSaleScreenState();
}

class _FlashSaleScreenState extends State<FlashSaleScreen> {
  final _api = ApiClient();
  Site? _selectedSite;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _points = [];
  int? _selectedPointId;
  bool _loadingProfiles = false;
  bool _generating = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _loadProfiles(Site site) async {
    setState(() {
      _selectedSite = site;
      _loadingProfiles = true;
      _profiles = [];
      _result = null;
      _error = null;
    });
    try {
      final data = await _api.get(
          ApiConfig.flashSale, {'site_id': site.id.toString()});
      if (data['success'] == true) {
        final list = data['profiles'] as List? ?? [];
        final pts = data['points'] as List? ?? [];
        setState(() {
          _profiles = list.map((p) => Map<String, dynamic>.from(p)).toList();
          _points = pts.map((p) => Map<String, dynamic>.from(p)).toList();
          _selectedPointId = _points.isNotEmpty ? (_points.first['id'] is int ? _points.first['id'] : int.tryParse(_points.first['id'].toString())) : null;
        });
      } else {
        setState(() => _error = data['error'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _loadingProfiles = false);
  }

  Future<void> _generate(String profileName) async {
    if (_selectedSite == null || _generating) return;
    setState(() {
      _generating = true;
      _result = null;
      _error = null;
    });
    try {
      final data = await _api.post(ApiConfig.flashSale, {
        'site_id': _selectedSite!.id,
        'profile': profileName,
        if (_selectedPointId != null) 'point_id': _selectedPointId,
      });
      if (data['success'] == true) {
        setState(() => _result = data);
      } else {
        setState(() => _error = data['error'] ?? 'Erreur generation');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final sites = context.watch<SiteProvider>().sites;

    return PopScope(
      canPop: _selectedSite == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() { _selectedSite = null; _profiles = []; _result = null; _error = null; });
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Vente Flash'),
        actions: [
          if (_selectedSite != null)
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Changer de site',
              onPressed: () => setState(() {
                _selectedSite = null;
                _profiles = [];
                _result = null;
              }),
            ),
        ],
      ),
      body: _selectedSite == null
          ? _buildSiteSelector(sites)
          : _loadingProfiles
              ? const Center(child: CircularProgressIndicator())
              : _result != null
                  ? _buildResult()
                  : _buildProfileGrid(),
    ),
    );
  }

  Widget _buildSiteSelector(List<Site> sites) {
    final configured = sites.where((s) => s.isConfigured).toList();
    if (configured.isEmpty) {
      return Center(
        child: Text('Aucun site configure',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: configured.length,
      itemBuilder: (_, i) {
        final site = configured[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(Icons.router,
                color: site.isOnline ? AppTheme.success : AppTheme.danger),
            title: Text(site.nom,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(site.routerIp,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _loadProfiles(site),
          ),
        );
      },
    );
  }

  Widget _buildProfileGrid() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppTheme.primary.withValues(alpha: 0.05),
          child: Text(
            _selectedSite!.nom,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (_points.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<int>(
              value: _selectedPointId,
              decoration: const InputDecoration(
                labelText: 'Point de vente',
                prefixIcon: Icon(Icons.storefront),
                isDense: true,
              ),
              items: _points.map((p) {
                final id = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0;
                return DropdownMenuItem(value: id, child: Text(p['name'] ?? ''));
              }).toList(),
              onChanged: (v) => setState(() => _selectedPointId = v),
            ),
          ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!,
                style: const TextStyle(color: AppTheme.danger, fontSize: 13)),
          ),
        if (_generating) const LinearProgressIndicator(),
        Expanded(
          child: _profiles.isEmpty
              ? Center(
                  child: Text('Aucun profil disponible',
                      style: TextStyle(color: Colors.grey.shade500)))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: _profiles.length,
                  itemBuilder: (_, i) {
                    final p = _profiles[i];
                    final price = p['ticket_price'];
                    final currency = p['currency'] ?? 'XOF';
                    final name = p['name'] ?? '';
                    final validity = p['validity_value'];
                    final unit = p['validity_unit'];
                    final units = {
                      'hours': 'h',
                      'days': 'j',
                      'weeks': 'sem',
                      'months': 'mois'
                    };
                    final duration = validity != null
                        ? '$validity${units[unit] ?? ''}'
                        : 'Illimite';

                    return Card(
                      elevation: 2,
                      child: InkWell(
                        onTap: _generating ? null : () => _generate(name),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.wifi, color: AppTheme.primary, size: 28),
                              const SizedBox(height: 8),
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text(duration,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12)),
                              if (price != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  Fmt.currency(
                                      num.tryParse('$price') ?? 0, currency),
                                  style: const TextStyle(
                                      color: AppTheme.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ],
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

  Widget _buildResult() {
    final code = _result!['code'] ?? '';
    final password = _result!['password'] ?? '';
    final profile = _result!['profile'] ?? '';
    final price = _result!['price'];
    final currency = _result!['currency'] ?? 'XOF';
    final duration = _result!['duration'] ?? '';
    final siteName = _result!['site_name'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: AppTheme.success, size: 64),
          const SizedBox(height: 16),
          const Text('Voucher genere !',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),

          // Ticket card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(siteName,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 12),
                  // Code
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      code,
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Mot de passe: $password',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600)),
                  const SizedBox(height: 16),
                  // Info row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _infoChip(Icons.wifi, profile),
                      _infoChip(Icons.timer, duration),
                      if (price != null)
                        _infoChip(Icons.payments,
                            Fmt.currency(price as num, currency)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: 'Code: $code / Pass: $password'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copie !')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() {
                    _result = null;
                    _error = null;
                  }),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Nouvelle vente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
