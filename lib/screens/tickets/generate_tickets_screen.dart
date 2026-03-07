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

  @override
  Widget build(BuildContext context) {
    if (_generatedTickets != null) return _buildResultScreen();
    return _buildFormScreen();
  }

  Widget _buildFormScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Générer des tickets'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
      body: _loadingProfiles
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(child: Text('Aucun profil disponible'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedProfile,
                        decoration: const InputDecoration(
                          labelText: 'Profil',
                          border: OutlineInputBorder(),
                        ),
                        items: _profiles.map((p) {
                          final name = (p['name'] ?? '') as String;
                          final price = p['ticket_price'];
                          final label =
                              price != null ? '$name ($price FCFA)' : name;
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
                        decoration: const InputDecoration(
                          labelText: 'Quantité (1-200)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _generating ? null : _generate,
                        icon: _generating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.bolt),
                        label: Text(
                            _generating ? 'Génération...' : 'Générer'),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildResultScreen() {
    final tickets = _generatedTickets!;
    final profile = tickets.isNotEmpty ? tickets[0]['profile'] ?? '' : '';
    final price = tickets.isNotEmpty ? tickets[0]['price'] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets générés'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.success.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${tickets.length} ticket(s) générés, $_synced synchronisés',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          if (profile.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('Profil: $profile',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  if (price != null) ...[
                    const Spacer(),
                    Text('$price FCFA',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharePdf,
                    icon: const Icon(Icons.share, size: 20),
                    label: const Text('Partager PDF'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
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
                    icon: const Icon(Icons.picture_as_pdf, size: 20),
                    label: const Text('Télécharger'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: tickets.length,
              itemBuilder: (ctx, i) {
                final t = tickets[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.15),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary)),
                    ),
                    title: Text(t['code'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 1.5)),
                    subtitle: Text(
                        'Mot de passe: ${t['password'] ?? t['code']}',
                        style: const TextStyle(fontSize: 12)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
