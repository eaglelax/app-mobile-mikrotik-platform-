import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'formatters.dart';

/// Génère un PDF de tickets au format web (6 colonnes, pages remplies auto).
/// Style aligné sur l'app web : nom site, code, mot de passe, durée, prix, point.
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
  final password = (t['password'] ?? t['code'] ?? '').toString();
  final uptime = (t['uptime'] ??
          t['limit_uptime'] ??
          t['profile_limit_uptime'] ??
          t['duration'] ??
          '')
      .toString();
  final profile = (t['profile'] ?? t['profile_name'] ?? '').toString();
  final point = (t['point'] ?? t['point_name'] ?? '').toString();

  // Resolve price
  final price = _resolvePrice(t['price']) ?? _resolvePrice(t['ticket_price']);

  // Colors matching web app
  final headerBg = PdfColor.fromHex('#1e293b');
  final blue = PdfColor.fromHex('#1a73e8');
  final red = PdfColor.fromHex('#e53935');
  final grey = PdfColor.fromHex('#666666');
  final lightGrey = PdfColor.fromHex('#999999');
  final footerBg = PdfColor.fromHex('#f5f5f5');
  final borderColor = PdfColor.fromHex('#374151');
  final black = PdfColor.fromHex('#000000');

  return pw.Container(
    width: ticketWidth,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 0.5, color: borderColor),
      borderRadius: pw.BorderRadius.circular(2),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ── Header: Site name + ticket number ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
          decoration: pw.BoxDecoration(
            color: headerBg,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(1.5),
              topRight: pw.Radius.circular(1.5),
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
                '[${index + 1}]',
                style: pw.TextStyle(
                  fontSize: 5,
                  color: PdfColor.fromHex('#94a3b8'),
                  font: pw.Font.courier(),
                ),
              ),
            ],
          ),
        ),

        // ── Body: Code + Password + Details ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Code (username) — blue, bold, monospace
              pw.Text(
                code,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  font: pw.Font.courierBold(),
                  letterSpacing: 0.8,
                  color: blue,
                ),
              ),
              pw.SizedBox(height: 1.5),
              // Password — bold, monospace, with background
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                decoration: pw.BoxDecoration(
                  color: footerBg,
                  borderRadius: pw.BorderRadius.circular(1),
                ),
                child: pw.Text(
                  password,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.courierBold(),
                    letterSpacing: 0.5,
                    color: black,
                  ),
                ),
              ),
              pw.SizedBox(height: 2),
              // Details: durée / validité
              if (uptime.isNotEmpty)
                pw.Text(
                  uptime,
                  style: pw.TextStyle(
                    fontSize: 5.5,
                    color: grey,
                  ),
                ),
              // Prix — rouge, gros, bold (comme le web)
              if (price != null && price > 0) ...[
                pw.SizedBox(height: 1.5),
                pw.Text(
                  Fmt.currency(price, currency),
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: red,
                  ),
                ),
              ],
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
                color: blue,
              ),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
            ),
          ),

        // ── Footer: profil ou durée ──
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(
                  width: 0.3, color: PdfColor.fromHex('#dddddd')),
            ),
          ),
          child: pw.Text(
            profile.isNotEmpty ? profile : siteName,
            style: pw.TextStyle(
              fontSize: 5,
              color: lightGrey,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    ),
  );
}

/// Parse a dynamic value to num, returning null if 0 or unparseable.
num? _resolvePrice(dynamic val) {
  if (val == null) return null;
  final p = val is num ? val : num.tryParse(val.toString());
  if (p == null || p <= 0) return null;
  return p;
}
