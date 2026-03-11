import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import '../../services/ticket_service.dart';

class GenerateTicketsScreen extends StatefulWidget {
  final Site site;
  const GenerateTicketsScreen({super.key, required this.site});

  @override
  State<GenerateTicketsScreen> createState() => _GenerateTicketsScreenState();
}

class _GenerateTicketsScreenState extends State<GenerateTicketsScreen> {
  final _service = MikhmonService();
  final _ticketService = TicketService();
  final _qtyController = TextEditingController(text: '10');

  List<Map<String, dynamic>> _profiles = [];
  String? _selectedProfile;
  bool _loadingProfiles = true;
  bool _generating = false;

  // Result after generation
  List<Map<String, dynamic>>? _generatedTickets;
  int _synced = 0;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    try {
      final data = await _service.fetchProfiles(widget.site.id);
      _profiles =
          (data['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loadingProfiles = false);
  }

  Future<void> _generate() async {
    if (_selectedProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un profil')),
      );
      return;
    }
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty < 1 || qty > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantité entre 1 et 200')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final result = await _ticketService.generateBatch(
        widget.site.id,
        profile: _selectedProfile!,
        quantity: qty,
      );
      if (mounted) {
        final tickets = (result['tickets'] as List? ?? [])
            .cast<Map<String, dynamic>>();
        setState(() {
          _generatedTickets = tickets;
          _synced = (result['synced'] as num?)?.toInt() ?? 0;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        setState(() => _generating = false);
      }
    }
  }

  Future<File> _generatePdf() async {
    final tickets = _generatedTickets!;
    final pdf = pw.Document();
    final siteName = widget.site.nom;
    final profile = tickets.isNotEmpty ? tickets[0]['profile'] ?? '' : '';
    final price = tickets.isNotEmpty ? tickets[0]['price'] : null;

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
                  pw.Text('Profil: $profile',
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
              if (price != null)
                pw.Text('Prix: $price FCFA',
                    style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pageTickets.map((t) {
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
                        pw.Text(profile,
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
                        if (price != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('$price FCFA',
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
  Color get _fieldFill => _isDark ? AppTheme.darkCard : Colors.white;
  Color get _textPrimary => _isDark ? Colors.white : Colors.black87;
  Color get _textSecondary =>
      _isDark ? Colors.grey.shade400 : Colors.grey.shade600;

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textSecondary, fontSize: 14),
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
      ),
    );
  }

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

  Widget _buildFormScreen() {
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
                          child: Text(
                            'Aucun profil disponible',
                            style: TextStyle(color: _textSecondary),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Container(
                            decoration: _containerDecoration,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Configuration',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                DropdownButtonFormField<String>(
                                  value: _selectedProfile,
                                  decoration: _inputDecoration('Profil'),
                                  dropdownColor: _cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  style: TextStyle(
                                      color: _textPrimary, fontSize: 15),
                                  items: _profiles.map((p) {
                                    final name =
                                        (p['name'] ?? '') as String;
                                    final price = p['ticket_price'];
                                    final label = price != null
                                        ? '$name ($price FCFA)'
                                        : name;
                                    return DropdownMenuItem<String>(
                                      value: name,
                                      child: Text(label),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedProfile = v),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                      color: _textPrimary, fontSize: 15),
                                  decoration:
                                      _inputDecoration('Quantité (1-200)'),
                                ),
                                const SizedBox(height: 28),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _generating ? null : _generate,
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
                                          : 'Générer',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      disabledBackgroundColor: AppTheme
                                          .primary
                                          .withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16),
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
    final profile =
        tickets.isNotEmpty ? tickets[0]['profile'] ?? '' : '';
    final price = tickets.isNotEmpty ? tickets[0]['price'] : null;

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

            if (profile.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    Text('Profil: $profile',
                        style: TextStyle(
                            color: _textSecondary, fontSize: 13)),
                    if (price != null) ...[
                      const Spacer(),
                      Text('$price FCFA',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _textPrimary)),
                    ],
                  ],
                ),
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
                          'Mot de passe: ${t['password'] ?? t['code']}',
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
