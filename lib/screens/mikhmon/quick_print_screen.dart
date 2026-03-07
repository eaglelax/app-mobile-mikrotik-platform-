import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';

class QuickPrintScreen extends StatefulWidget {
  final Site site;
  const QuickPrintScreen({super.key, required this.site});

  @override
  State<QuickPrintScreen> createState() => _QuickPrintScreenState();
}

class _QuickPrintScreenState extends State<QuickPrintScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _profiles = [];
  String? _selectedProfile;
  int _quantity = 5;
  bool _loading = true;
  bool _generating = false;

  // Result after generation
  List<Map<String, dynamic>>? _generatedTickets;
  int _synced = 0;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchProfiles(widget.site.id);
      _profiles =
          (data['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generate() async {
    if (_selectedProfile == null) return;
    setState(() => _generating = true);

    try {
      final result = await _service.generateVouchers(widget.site.id, {
        'profile_name': _selectedProfile,
        'quantity': _quantity,
      });
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
          SnackBar(
              content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
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
    const ticketsPerPage = 15;

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
            const Text('Quick Print'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Profil',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProfile,
                    decoration:
                        const InputDecoration(hintText: 'Choisir un profil'),
                    items: _profiles
                        .map((p) => DropdownMenuItem<String>(
                              value: p['name'],
                              child: Text(p['name'] ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedProfile = v),
                  ),
                  const SizedBox(height: 20),
                  const Text('Quantité',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final q in [5, 10, 20, 50])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$q'),
                            selected: _quantity == q,
                            onSelected: (_) => setState(() => _quantity = q),
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: _quantity == q ? Colors.white : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _generating || _selectedProfile == null
                        ? null
                        : _generate,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.print),
                    label: Text(_generating
                        ? 'Génération...'
                        : 'Générer $_quantity tickets'),
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
                        await _generatePdf();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PDF sauvegardé'),
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
