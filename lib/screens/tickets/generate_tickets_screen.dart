import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/pdf_ticket_builder.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../models/point.dart';
import '../../services/mikhmon_service.dart';
import '../../services/ticket_service.dart';
import '../../services/point_service_api.dart';
import '../../widgets/top_notification.dart';

class GenerateTicketsScreen extends StatefulWidget {
  final Site site;
  const GenerateTicketsScreen({super.key, required this.site});

  @override
  State<GenerateTicketsScreen> createState() => _GenerateTicketsScreenState();
}

class _GenerateTicketsScreenState extends State<GenerateTicketsScreen> {
  final _service = MikhmonService();
  final _ticketService = TicketService();
  final _pointApi = PointServiceApi();
  final _qtyController = TextEditingController(text: '10');

  List<Map<String, dynamic>> _profiles = [];
  List<Point> _points = [];
  Set<String> _selectedProfiles = {};
  Point? _selectedPoint;
  bool _loadingProfiles = true;
  bool _generating = false;

  // Result after generation — grouped by profile
  Map<String, List<Map<String, dynamic>>>? _ticketsByProfile;
  int _synced = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _service.fetchProfiles(widget.site.id),
        _pointApi.fetchBySite(widget.site.id),
      ]);
      final profileData = results[0] as Map<String, dynamic>;
      if (profileData['success'] == true) {
        _profiles =
            (profileData['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
      }
      _points = results[1] as List<Point>;
      // Pré-sélectionner si un seul point actif
      final active = _points.where((p) => p.isActive).toList();
      if (active.length == 1) {
        _selectedPoint = active.first;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingProfiles = false);
  }

  Future<void> _generate() async {
    if (_selectedProfiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un profil')),
      );
      return;
    }
    if (_selectedPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un point de vente')),
      );
      return;
    }
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty < 1 || qty > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantité entre 1 et 2000')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      // Launch generation for all selected profiles in parallel
      final futures = _selectedProfiles.map((profileName) {
        return _ticketService.generateBatch(
          widget.site.id,
          profile: profileName,
          quantity: qty,
          pointId: _selectedPoint?.id,
        );
      }).toList();

      final results = await Future.wait(futures);

      if (mounted) {
        final grouped = <String, List<Map<String, dynamic>>>{};
        int totalCount = 0;
        int totalSynced = 0;
        for (int i = 0; i < results.length; i++) {
          final result = results[i];
          final profileName = _selectedProfiles.elementAt(i);
          final tickets = (result['tickets'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          grouped[profileName] = tickets;
          totalCount += tickets.length;
          totalSynced += (result['synced'] as num?)?.toInt() ?? 0;
        }
        setState(() {
          _ticketsByProfile = grouped;
          _synced = totalSynced;
          _generating = false;
        });
        TopNotification.show(
          context,
          title: 'Génération terminée',
          message: '$totalCount ticket(s) générés — $totalSynced synchronisés',
        );
        _showSuccessDialog(totalCount, totalSynced);
      }
    } catch (e) {
      if (mounted) {
        // Timeout = la génération continue en arrière-plan sur le serveur
        final errStr = e.toString();
        final isTimeout = errStr.contains('TimeoutException') || errStr.contains('502');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isTimeout ? Icons.cloud_sync : Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isTimeout
                        ? 'Génération en cours en arrière-plan. Les tickets seront disponibles dans quelques instants.'
                        : 'Erreur: $e',
                  ),
                ),
              ],
            ),
            backgroundColor: isTimeout ? Colors.orange : Colors.red,
            duration: Duration(seconds: isTimeout ? 6 : 4),
          ),
        );
        setState(() => _generating = false);
      }
    }
  }

  void _showSuccessDialog(int count, int synced) {
    final profileLabel = _selectedProfiles.join(', ');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _isDark ? AppTheme.darkCard : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppTheme.success, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Génération terminée',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _dialogInfoRow(Icons.confirmation_number, '$count ticket(s) générés'),
                    const SizedBox(height: 10),
                    _dialogInfoRow(Icons.sync, '$synced synchronisés au routeur'),
                    const SizedBox(height: 10),
                    _dialogInfoRow(Icons.router, widget.site.nom),
                    const SizedBox(height: 10),
                    _dialogInfoRow(Icons.person, profileLabel),
                    if (_selectedPoint != null) ...[
                      const SizedBox(height: 10),
                      _dialogInfoRow(Icons.store, _selectedPoint!.name),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary)),
        ),
      ],
    );
  }

  Future<File> _generatePdf(String profileName) async {
    final tickets = _ticketsByProfile![profileName] ?? [];
    return generateTicketsPdf(
      tickets: tickets,
      siteName: widget.site.nom,
    );
  }

  Future<void> _sharePdf(String profileName) async {
    try {
      final file = await _generatePdf(profileName);
      final totalCount = _ticketsByProfile![profileName]?.length ?? 0;
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tickets ${widget.site.nom} - $totalCount tickets ($profileName)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur partage: $e')),
        );
      }
    }
  }

  // -- UI Helpers --

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bg => _isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
  Color get _cardColor => _isDark ? AppTheme.darkCard : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get _textSecondary =>
      _isDark ? Colors.grey.shade400 : Colors.grey.shade600;

  BoxDecoration get _containerDecoration => BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isDark ? Colors.black : Colors.black12)
                .withValues(alpha: _isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _buildHeader(String title, {VoidCallback? onBack}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: _textPrimary, size: 22),
            onPressed: onBack ?? () => Navigator.pop(context),
            splashRadius: 22,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_ticketsByProfile != null) return _buildResultScreen();
    return _buildFormScreen();
  }

  Widget _dropdownContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: _isDark ? Colors.white70 : Colors.grey.shade700),
      ),
    );
  }

  Widget _buildFormScreen() {
    final activePoints = _points.where((p) => p.isActive).toList();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader('Générer des tickets'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                widget.site.nom,
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loadingProfiles
                  ? const Center(child: CircularProgressIndicator())
                  : _profiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.warning.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('Aucun profil disponible', style: TextStyle(fontSize: 13)),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => _loadingProfiles = true);
                                      _loadData();
                                    },
                                    child: const Icon(Icons.refresh, size: 18),
                                  ),
                                ]),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Container(
                            decoration: _containerDecoration,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Configuration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Les tickets seront créés sur le routeur hotspot',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                                const SizedBox(height: 20),

                                // Profile grid selector (multi-select)
                                Row(
                                  children: [
                                    Text('Profils', style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: _isDark ? Colors.white70 : Colors.grey.shade700,
                                    )),
                                    const Spacer(),
                                    if (_selectedProfiles.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => setState(() => _selectedProfiles.clear()),
                                        child: Text('Tout décocher', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 1.1,
                                  ),
                                  itemCount: _profiles.length,
                                  itemBuilder: (ctx, i) {
                                    final p = _profiles[i];
                                    final name = p['name'] ?? '';
                                    final price = p['ticket_price'];
                                    final selected = _selectedProfiles.contains(name);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (selected) {
                                            _selectedProfiles.remove(name);
                                          } else {
                                            _selectedProfiles.add(name);
                                          }
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppTheme.primary.withValues(alpha: _isDark ? 0.3 : 0.12)
                                              : (_isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA)),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: selected ? AppTheme.primary : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (selected)
                                              const Icon(Icons.check_circle, color: AppTheme.primary, size: 18)
                                            else
                                              Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 18),
                                            const SizedBox(height: 4),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                                color: selected ? AppTheme.primary : (_isDark ? Colors.white70 : Colors.black87),
                                              ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (price != null && price > 0)
                                              Text(
                                                '${price.toStringAsFixed(0)}F',
                                                style: TextStyle(fontSize: 10, color: _textSecondary),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                if (_selectedProfiles.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '${_selectedProfiles.length} profil(s) sélectionné(s)',
                                    style: TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Point de vente selector (obligatoire)
                                Row(
                                  children: [
                                    Text('Point de vente', style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: _isDark ? Colors.white70 : Colors.grey.shade700,
                                    )),
                                    const SizedBox(width: 4),
                                    Text('*', style: TextStyle(fontSize: 13, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (activePoints.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isDark ? Colors.grey.shade800 : const Color(0xFFF5F6FA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.warning_amber, size: 16, color: Colors.orange.shade400),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('Aucun point de vente configuré. Créez un point avant de générer des tickets.', style: TextStyle(fontSize: 13, color: Colors.orange.shade400))),
                                    ]),
                                  )
                                else
                                  _dropdownContainer(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        isExpanded: true,
                                        value: _selectedPoint?.id,
                                        hint: Text('Sélectionnez un point', style: TextStyle(color: Colors.red.shade300, fontSize: 14)),
                                        dropdownColor: _isDark ? AppTheme.darkCard : Colors.white,
                                        items: [
                                          ...activePoints.map((p) {
                                            return DropdownMenuItem<int>(
                                              value: p.id,
                                              child: Text(p.name,
                                                  style: TextStyle(fontSize: 14, color: _isDark ? Colors.white : Colors.black87),
                                                  overflow: TextOverflow.ellipsis),
                                            );
                                          }),
                                        ],
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedPoint = val != null
                                                ? activePoints.firstWhere((p) => p.id == val)
                                                : null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 16),

                                // Quantity input with +/- buttons
                                Text('Quantité', style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: _isDark ? Colors.white70 : Colors.grey.shade700,
                                )),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _qtyButton(Icons.remove, () {
                                      final current = int.tryParse(_qtyController.text) ?? 10;
                                      if (current > 1) {
                                        setState(() => _qtyController.text = (current - 5).clamp(1, 2000).toString());
                                      }
                                    }),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _qtyController,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w700,
                                          color: _isDark ? Colors.white : Colors.black87,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: _isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _qtyButton(Icons.add, () {
                                      final current = int.tryParse(_qtyController.text) ?? 10;
                                      setState(() => _qtyController.text = (current + 5).clamp(1, 2000).toString());
                                    }),
                                  ],
                                ),

                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        (_generating || _selectedProfiles.isEmpty || _selectedPoint == null) ? null : _generate,
                                    icon: _generating
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child:
                                                CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white),
                                          )
                                        : const Icon(Icons.bolt,
                                            color: Colors.white),
                                    label: Text(
                                      _generating
                                          ? 'Génération...'
                                          : 'Générer les tickets',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      disabledBackgroundColor: AppTheme
                                          .primary
                                          .withValues(alpha: 0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final data = _ticketsByProfile!;
    final totalCount = data.values.fold<int>(0, (s, l) => s + l.length);
    final profileEntries = data.entries.where((e) => e.value.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(
              'Tickets générés',
              onBack: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 4),

            // Success banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: _isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$totalCount ticket(s) générés en ${profileEntries.length} lot(s)',
                        style: TextStyle(fontWeight: FontWeight.w600, color: _textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pas de PDF global — chaque profil a son propre PDF

            const SizedBox(height: 8),

            // Profile lots
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                itemCount: profileEntries.length,
                itemBuilder: (ctx, profileIndex) {
                  final profileName = profileEntries[profileIndex].key;
                  final tickets = profileEntries[profileIndex].value;
                  return _buildProfileSection(profileName, tickets, profileIndex);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(String profileName, List<Map<String, dynamic>> tickets, int colorIndex) {
    final colors = [AppTheme.primary, Colors.teal, Colors.deepPurple, Colors.orange, Colors.pink];
    final color = colors[colorIndex % colors.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile header
        Container(
          margin: const EdgeInsets.only(bottom: 8, top: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(Icons.confirmation_number, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profileName,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _textPrimary)),
                    Text('${tickets.length} ticket(s)',
                        style: TextStyle(fontSize: 12, color: _textSecondary)),
                  ],
                ),
              ),
              // PDF button per profile
              IconButton(
                icon: Icon(Icons.picture_as_pdf, color: color, size: 22),
                tooltip: 'PDF $profileName',
                onPressed: () async {
                  try {
                    final file = await _generatePdf(profileName);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF $profileName sauvegardé'), backgroundColor: AppTheme.success),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.share, color: color, size: 20),
                tooltip: 'Partager $profileName',
                onPressed: () => _sharePdf(profileName),
              ),
            ],
          ),
        ),

        // Ticket cards for this profile
        ...tickets.asMap().entries.map((entry) {
          final i = entry.key;
          final t = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: _containerDecoration,
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: _isDark ? 0.25 : 0.12),
                child: Text('${i + 1}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
              title: Text(t['code'] ?? '',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1.5, color: _textPrimary)),
              subtitle: Text(
                  'MDP: ${t['password'] ?? t['code']}${t['price'] != null ? ' · ${t['price']} FCFA' : ''}',
                  style: TextStyle(fontSize: 12, color: _textSecondary)),
            ),
          );
        }),

        const SizedBox(height: 8),
      ],
    );
  }
}
