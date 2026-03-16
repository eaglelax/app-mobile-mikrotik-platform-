import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'formatters.dart';

/// Génère un PDF de tickets au format web (6 colonnes, pages remplies auto).
/// Par défaut sauvegarde dans le dossier temporaire (pour partage).
/// Avec [toDownloads] = true, sauvegarde dans le dossier Téléchargements.
Future<File> generateTicketsPdf({
  required List<Map<String, dynamic>> tickets,
  required String siteName,
  String? fileName,
  String currency = 'FCFA',
  bool toDownloads = false,
}) async {
  final pdf = pw.Document();

  const ticketsPerRow = 6;
  const pageMargin = 14.17; // ~5mm
  const gap = 2.3; // ~0.8mm

  final ticketWidth =
      (PdfPageFormat.a4.width - pageMargin * 2 - gap * (ticketsPerRow - 1)) /
          ticketsPerRow;

  // Construire tous les widgets tickets
  final ticketWidgets = tickets.asMap().entries.map((entry) {
    return _buildTicket(
      t: entry.value,
      index: entry.key,
      siteName: siteName,
      ticketWidth: ticketWidth,
      currency: currency,
    );
  }).toList();

  // MultiPage remplit chaque page automatiquement et gère les sauts
  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(pageMargin),
    build: (context) => [
      pw.Wrap(
        spacing: gap,
        runSpacing: gap,
        children: ticketWidgets,
      ),
    ],
  ));

  final name = fileName ??
      'tickets_${siteName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}';
  final bytes = await pdf.save();

  // Dossier de destination
  Directory dir;
  if (toDownloads && Platform.isAndroid) {
    dir = Directory('/storage/emulated/0/Download');
    if (!await dir.exists()) {
      dir = await getTemporaryDirectory();
    }
  } else {
    dir = await getTemporaryDirectory();
  }

  final file = File('${dir.path}/$name.pdf');
  await file.writeAsBytes(bytes);
  return file;
}

pw.Widget _buildTicket({
  required Map<String, dynamic> t,
  required int index,
  required String siteName,
  required double ticketWidth,
  required String currency,
}) {
  final code = (t['code'] ?? t['name'] ?? '').toString();
  final uptime =
      (t['uptime'] ?? t['limit_uptime'] ?? t['duration'] ?? '').toString();
  final price = t['price'];
  final point =
      (t['point'] ?? t['point_name'] ?? '').toString();

  // Footer: durée · prix  ou juste profil
  final footParts = <String>[];
  if (uptime.isNotEmpty) footParts.add(uptime);
  if (price != null) {
    final p = price is num ? price : num.tryParse(price.toString());
    if (p != null && p > 0) footParts.add(Fmt.currency(p, currency));
  }
  if (footParts.isEmpty) {
    final profile =
        (t['profile'] ?? t['profile_name'] ?? '').toString();
    if (profile.isNotEmpty) footParts.add(profile);
  }
  final footLine = footParts.join(' \u00b7 ');

  return pw.Container(
    width: ticketWidth,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(
          width: 0.3, color: PdfColor.fromHex('#374151')),
      borderRadius: pw.BorderRadius.circular(3),
    ),
    child: pw.Column(
      children: [
        // ── Dark header ──
        pw.Container(
          width: double.infinity,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#1e293b'),
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(2.5),
              topRight: pw.Radius.circular(2.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  siteName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ),
              pw.Text(
                '#${index + 1}',
                style: pw.TextStyle(
                  fontSize: 5,
                  color: PdfColor.fromHex('#94a3b8'),
                  font: pw.Font.courier(),
                ),
              ),
            ],
          ),
        ),

        // ── Body: label + code ──
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Column(
            children: [
              pw.Text(
                'MOT DE PASSE',
                style: pw.TextStyle(
                  fontSize: 5,
                  color: PdfColor.fromHex('#94a3b8'),
                  letterSpacing: 0.3,
                ),
              ),
              pw.SizedBox(height: 1.5),
              pw.Text(
                code,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  font: pw.Font.courierBold(),
                  letterSpacing: 0.5,
                  color: PdfColor.fromHex('#0f172a'),
                ),
              ),
            ],
          ),
        ),

        // ── Point de vente (si disponible) ──
        if (point.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1),
            child: pw.Text(
              point,
              style: pw.TextStyle(
                fontSize: 5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#2563eb'),
              ),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),

        // ── Footer: durée · prix ──
        pw.Container(
          width: double.infinity,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#f0f4f8'),
            border: pw.Border(
              top: pw.BorderSide(
                  width: 0.3, color: PdfColor.fromHex('#cbd5e1')),
            ),
          ),
          child: pw.Text(
            footLine,
            style: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#334155'),
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    ),
  );
}
