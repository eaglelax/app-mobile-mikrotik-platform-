import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../models/point.dart';
import '../../services/mikhmon_service.dart';
import '../../services/ticket_service.dart';
import '../../services/point_service_api.dart';

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

  // Result after generation
  List<Map<String, dynamic>>? _generatedTickets;
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
        final allTickets = <Map<String, dynamic>>[];
        int totalSynced = 0;
        for (final result in results) {
          final tickets = (result['tickets'] as List? ?? [])
              .cast<Map<String, dynamic>>();
          allTickets.addAll(tickets);
          totalSynced += (result['synced'] as num?)?.toInt() ?? 0;
        }
        setState(() {
          _generatedTickets = allTickets;
          _synced = totalSynced;
          _generating = false;
        });
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

  Future<File> _generatePdf() async {
    final tickets = _generatedTickets!;
    final pdf = pw.Document();
    final siteName = widget.site.nom;
    final profileNames = tickets.map((t) => t['profile'] ?? '').toSet().join(', ');

    const ticketsPerRow = 3;
    const ticketsPerPage = 15; // 3 cols x 5 rows

    for (var pageStart = 0;
        pageStart < tickets.length;
        pageStart += ticketsPerPage) {
      final pageEnd = (pageStart + ticketsPerPage > tickets.length)
          ? tickets.length
          : pageStart + ticketsPerPage;
      final pageTickets = tickets.sublist(pageStart, pageEnd);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(siteName,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Profils: $profileNames',
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pageTickets.map((t) {
                  final tProfile = t['profile'] ?? '';
                  final tPrice = t['price'];
                  return pw.Container(
                    width: (PdfPageFormat.a4.width - 40 - 16) / ticketsPerRow,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(siteName,
                            style: pw.TextStyle(
                                fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(tProfile,
                            style: const pw.TextStyle(fontSize: 6)),
                        pw.SizedBox(height: 4),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(t['code'] ?? '',
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('Mot de passe: ${t['password'] ?? t['code']}',
                            style: const pw.TextStyle(fontSize: 6)),
                        if (tPrice != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('$tPrice FCFA',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  fontWeight: pw.FontWeight.bold)),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ));
    }

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/tickets_${siteName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _sharePdf() async {
    try {
      final file = await _generatePdf();
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Tickets ${widget.site.nom} - ${_generatedTickets!.length} tickets',
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
    if (_generatedTickets != null) return _buildResultScreen();
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

                                // Point de vente selector
                                Text('Point de vente', style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: _isDark ? Colors.white70 : Colors.grey.shade700,
                                )),
                                const SizedBox(height: 8),
                                if (activePoints.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isDark ? Colors.grey.shade800 : const Color(0xFFF5F6FA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(children: [
                                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade400),
                                      const SizedBox(width: 8),
                                      Text('Aucun point de vente configuré', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                                    ]),
                                  )
                                else
                                  _dropdownContainer(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        isExpanded: true,
                                        value: _selectedPoint?.id,
                                        hint: Text('Tous (optionnel)', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                                        dropdownColor: _isDark ? AppTheme.darkCard : Colors.white,
                                        items: [
                                          DropdownMenuItem<int>(
                                            value: null,
                                            child: Text('Tous les points', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                                          ),
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
                                        (_generating || _selectedProfiles.isEmpty) ? null : _generate,
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
    final tickets = _generatedTickets!;
    // Group profiles for display
    final profileNames = tickets.map((t) => t['profile'] ?? '').toSet();
    final profileLabel = profileNames.join(', ');

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
                  color: AppTheme.success
                      .withValues(alpha: _isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppTheme.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${tickets.length} ticket(s) générés, $_synced synchronisés',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (profileLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                child: Text('Profils: $profileLabel',
                    style: TextStyle(
                        color: _textSecondary, fontSize: 13)),
              ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _sharePdf,
                        icon: const Icon(Icons.share, size: 20),
                        label: const Text('Partager PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: AppTheme.primary
                                .withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final file = await _generatePdf();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'PDF sauvegardé: ${file.path.split('/').last}'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Erreur: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf,
                            size: 20, color: Colors.white),
                        label: const Text(
                          'Télécharger',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Ticket list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                itemCount: tickets.length,
                itemBuilder: (ctx, i) {
                  final t = tickets[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: _containerDecoration,
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primary
                            .withValues(alpha: _isDark ? 0.25 : 0.12),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary)),
                      ),
                      title: Text(t['code'] ?? '',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 1.5,
                              color: _textPrimary)),
                      subtitle: Text(
                          '${t['profile'] ?? ''} · MDP: ${t['password'] ?? t['code']}',
                          style: TextStyle(
                              fontSize: 12, color: _textSecondary)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
