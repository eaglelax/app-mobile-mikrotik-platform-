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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final containerColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: containerColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Print',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      Text(
                        widget.site.nom,
                        style: TextStyle(fontSize: 13, color: subtitleColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primary,
                        strokeWidth: 2.5,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Profile selector container
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: containerColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Profil',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedProfile,
                                  decoration: InputDecoration(
                                    hintText: 'Choisir un profil',
                                    hintStyle: TextStyle(color: subtitleColor),
                                    filled: true,
                                    fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: borderColor),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  dropdownColor: containerColor,
                                  style: TextStyle(color: textColor, fontSize: 14),
                                  items: _profiles
                                      .map((p) => DropdownMenuItem<String>(
                                            value: p['name'],
                                            child: Text(p['name'] ?? ''),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedProfile = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Quantity selector container
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: containerColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quantite',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    for (final q in [5, 10, 20, 50])
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8),
                                        child: GestureDetector(
                                          onTap: () =>
                                              setState(() => _quantity = q),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 18, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: _quantity == q
                                                  ? AppTheme.primary
                                                  : isDark
                                                      ? AppTheme.darkSurface
                                                      : const Color(0xFFF0F1F5),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: _quantity == q
                                                  ? null
                                                  : Border.all(
                                                      color: borderColor),
                                            ),
                                            child: Text(
                                              '$q',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: _quantity == q
                                                    ? Colors.white
                                                    : textColor,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Generate button
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed:
                                  _generating || _selectedProfile == null
                                      ? null
                                      : _generate,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                disabledBackgroundColor: isDark
                                    ? AppTheme.darkSurface
                                    : const Color(0xFFD0D5DD),
                                foregroundColor: Colors.white,
                                disabledForegroundColor: isDark
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade400,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_generating)
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  else
                                    const Icon(Icons.print, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    _generating
                                        ? 'Generation...'
                                        : 'Generer $_quantity tickets',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final containerColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE8EAF0);

    final tickets = _generatedTickets!;
    final profile = tickets.isNotEmpty ? tickets[0]['profile'] ?? '' : '';
    final price = tickets.isNotEmpty ? tickets[0]['price'] : null;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: containerColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Tickets generes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            // Success banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${tickets.length} ticket(s) generes, $_synced synchronises',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (profile.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Text('Profil: $profile',
                        style: TextStyle(color: subtitleColor, fontSize: 13)),
                    if (price != null) ...[
                      const Spacer(),
                      Text('$price FCFA',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: textColor,
                          )),
                    ],
                  ],
                ),
              ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            color: isDark
                                ? AppTheme.primary.withValues(alpha: 0.5)
                                : AppTheme.primary.withValues(alpha: 0.4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await _generatePdf();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PDF sauvegarde'),
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
                        label: const Text('Telecharger'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: tickets.length,
                itemBuilder: (ctx, i) {
                  final t = tickets[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: containerColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t['code'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 1.5,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mot de passe: ${t['password'] ?? t['code']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
