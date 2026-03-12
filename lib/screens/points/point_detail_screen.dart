import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../models/site.dart';
import '../../services/ticket_service.dart';
import '../../services/mikhmon_service.dart';
import 'point_form_screen.dart';
import 'gerants_screen.dart';

class PointDetailScreen extends StatefulWidget {
  final Point point;
  final Site site;
  const PointDetailScreen({super.key, required this.point, required this.site});

  @override
  State<PointDetailScreen> createState() => _PointDetailScreenState();
}

class _PointDetailScreenState extends State<PointDetailScreen>
    with SingleTickerProviderStateMixin {
  final _ticketService = TicketService();
  final _mikhmonService = MikhmonService();

  late TabController _tabController;

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _vouchers = [];
  List<Map<String, dynamic>> _batches = [];
  List<Map<String, dynamic>> _profiles = [];
  bool _loadingProfiles = false;
  // Generation state
  bool _generating = false;
  Map<String, dynamic>? _selectedProfile;
  final _qtyController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ticketService.fetchPointTickets(
        widget.site.id,
        widget.point.id,
      );
      if (data['success'] == true) {
        _stats = (data['stats'] as Map<String, dynamic>?) ?? {};
        _vouchers =
            (data['vouchers'] as List? ?? []).cast<Map<String, dynamic>>();
        _batches =
            (data['batches'] as List? ?? []).cast<Map<String, dynamic>>();

      } else {
        _error = data['error']?.toString() ?? 'Erreur lors du chargement';
      }
    } catch (e) {
      _error = 'Connexion échouée: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfiles() async {
    setState(() => _loadingProfiles = true);
    try {
      final data = await _mikhmonService.fetchProfiles(widget.site.id);
      if (data['success'] == true) {
        _profiles =
            (data['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingProfiles = false);
  }

  // ── PDF Generation ──

  Future<File> _generatePdfFromTickets(List<Map<String, dynamic>> tickets,
      {String? profileName, dynamic price}) async {
    final pdf = pw.Document();
    final siteName = widget.site.nom;
    final profile = profileName ?? (tickets.isNotEmpty ? tickets[0]['profile_name'] ?? '' : '');
    final pointName = widget.point.name;

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
                  pw.Text('Point: $pointName',
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Profil: $profile',
                      style: const pw.TextStyle(fontSize: 10)),
                  if (price != null)
                    pw.Text('Prix: $price FCFA',
                        style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pageTickets.map((t) {
                  final code = t['code'] ?? t['name'] ?? '';
                  final pass = t['password'] ?? code;
                  final tProfile = t['profile_name'] ?? t['profile'] ?? profile;
                  return pw.Container(
                    width:
                        (PdfPageFormat.a4.width - 40 - 16) / ticketsPerRow,
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
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 1),
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
                          child: pw.Text(code,
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('Mot de passe: $pass',
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
        '${dir.path}/tickets_${pointName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _shareBatchPdf(Map<String, dynamic> batch) async {
    try {
      // Fetch batch detail from API
      final batchId = batch['batch_id'] as String;
      final data =
          await _ticketService.fetchBatchDetail(widget.site.id, batchId);
      if (data['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Erreur: ${data['error'] ?? 'Lot introuvable'}'),
                backgroundColor: AppTheme.danger),
          );
        }
        return;
      }

      final tickets =
          (data['tickets'] as List? ?? []).cast<Map<String, dynamic>>();
      if (tickets.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Aucun ticket dans ce lot'),
                backgroundColor: AppTheme.warning),
          );
        }
        return;
      }

      final profileName = batch['profile_name'] ?? '';
      final batchInfo = data['batch'] as Map<String, dynamic>?;
      final price = batchInfo?['price'] ?? tickets.first['ticket_price'];

      final file = await _generatePdfFromTickets(tickets,
          profileName: profileName, price: price);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Tickets ${widget.site.nom} - ${widget.point.name} - ${tickets.length} tickets',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur partage: $e'),
              backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  Future<void> _downloadBatchPdf(Map<String, dynamic> batch) async {
    try {
      final batchId = batch['batch_id'] as String;
      final data =
          await _ticketService.fetchBatchDetail(widget.site.id, batchId);
      if (data['success'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Erreur: ${data['error'] ?? 'Lot introuvable'}'),
                backgroundColor: AppTheme.danger),
          );
        }
        return;
      }

      final tickets =
          (data['tickets'] as List? ?? []).cast<Map<String, dynamic>>();
      if (tickets.isEmpty) return;

      final profileName = batch['profile_name'] ?? '';
      final batchInfo = data['batch'] as Map<String, dynamic>?;
      final price = batchInfo?['price'] ?? tickets.first['ticket_price'];

      final file = await _generatePdfFromTickets(tickets,
          profileName: profileName, price: price);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF sauvegardé: ${file.path.split('/').last}'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // ── Share available vouchers as PDF ──

  Future<void> _shareAvailableVouchersPdf() async {
    final available =
        _vouchers.where((v) => v['status'] == 'available').toList();
    if (available.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aucun ticket disponible à partager'),
              backgroundColor: AppTheme.warning),
        );
      }
      return;
    }
    try {
      final file = await _generatePdfFromTickets(available);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Tickets disponibles ${widget.site.nom} - ${widget.point.name} (${available.length})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // ── Generate ticket sheet ──

  void _showGenerateSheet() async {
    if (_profiles.isEmpty) await _loadProfiles();
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    _selectedProfile = null;
    _qtyController.text = '10';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Container(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Générer des tickets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1D21),
                      )),
                  const SizedBox(height: 4),
                  Text('Pour le point: ${widget.point.name}',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 20),

                  // Profile selector
                  Text('Profil',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      )),
                  const SizedBox(height: 8),
                  if (_loadingProfiles)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else if (_profiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.warning_amber,
                            color: AppTheme.warning, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Aucun profil disponible',
                                style: TextStyle(fontSize: 13))),
                        GestureDetector(
                          onTap: () {
                            _loadProfiles().then((_) {
                              if (mounted) setSheetState(() {});
                            });
                          },
                          child: const Icon(Icons.refresh, size: 18),
                        ),
                      ]),
                    )
                  else
                    _dropdownContainer(isDark,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _selectedProfile?['name'] as String?,
                            hint: Text('Choisir un profil',
                                style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14)),
                            dropdownColor:
                                isDark ? AppTheme.darkCard : Colors.white,
                            items: _profiles.map((p) {
                              final name = p['name'] ?? '';
                              final price = p['ticket_price'];
                              final stock = p['stock'];
                              final stockLabel =
                                  stock != null ? ' ($stock)' : '';
                              final priceLabel =
                                  price != null && price > 0
                                      ? ' - ${price.toStringAsFixed(0)} FCFA'
                                      : '';
                              return DropdownMenuItem(
                                value: name as String,
                                child: Text('$name$priceLabel$stockLabel',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87),
                                    overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setSheetState(() {
                                _selectedProfile = _profiles
                                    .firstWhere((p) => p['name'] == val);
                                final suggestion =
                                    _selectedProfile?['suggestion'];
                                if (suggestion != null && suggestion > 0) {
                                  _qtyController.text =
                                      suggestion.toString();
                                }
                              });
                            },
                          ),
                        )),

                  const SizedBox(height: 16),

                  // Quantity
                  Text('Quantité',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _qtyButton(Icons.remove, () {
                        final current =
                            int.tryParse(_qtyController.text) ?? 10;
                        if (current > 1) {
                          setSheetState(() => _qtyController.text =
                              (current - 5).clamp(1, 2000).toString());
                        }
                      }, isDark),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: isDark
                                ? AppTheme.darkBg
                                : const Color(0xFFF5F6FA),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _qtyButton(Icons.add, () {
                        final current =
                            int.tryParse(_qtyController.text) ?? 10;
                        setSheetState(() => _qtyController.text =
                            (current + 5).clamp(1, 2000).toString());
                      }, isDark),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Generate button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_generating || _selectedProfile == null)
                          ? null
                          : () async {
                              final qty =
                                  int.tryParse(_qtyController.text) ?? 0;
                              if (qty < 1 || qty > 2000) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Quantité entre 1 et 2000')),
                                );
                                return;
                              }
                              setSheetState(() => _generating = true);
                              try {
                                final profileName =
                                    _selectedProfile!['name'] as String;
                                final result =
                                    await _ticketService.generateBatch(
                                  widget.site.id,
                                  profile: profileName,
                                  quantity: qty,
                                  pointId: widget.point.id,
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                final generated = result['generated'] ??
                                    result['quantity'] ??
                                    qty;
                                final synced = result['synced'] ?? 0;

                                // Show result with share options
                                final tickets = (result['tickets'] as List? ?? [])
                                    .cast<Map<String, dynamic>>();
                                if (!mounted) return;

                                _generating = false;

                                if (tickets.isNotEmpty) {
                                  _showGenerationResult(
                                      tickets, generated, synced, profileName);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppTheme.success,
                                      content: Text(
                                        '$generated tickets générés ($synced synchronisés)',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                  );
                                }
                                _load(); // Refresh
                              } catch (e) {
                                if (!ctx.mounted) return;
                                setSheetState(() => _generating = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppTheme.danger,
                                    content: Text('Erreur: $e',
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        disabledBackgroundColor:
                            AppTheme.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _generating
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Générer les tickets',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ── Post-generation result sheet with PDF/Share ──

  void _showGenerationResult(List<Map<String, dynamic>> tickets, dynamic generated, dynamic synced, String profileName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = tickets.isNotEmpty ? tickets[0]['price'] : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Success header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$generated ticket(s) générés, $synced synchronisés',
                          style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF1A1D21),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Text('Profil: $profileName',
                        style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 13)),
                    if (price != null) ...[
                      const Spacer(),
                      Text('$price FCFA',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ],
                ),
              ),

              // Action buttons: Share PDF + Download PDF
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final file = await _generatePdfFromTickets(tickets,
                                  profileName: profileName, price: price);
                              await Share.shareXFiles(
                                [XFile(file.path)],
                                text: 'Tickets ${widget.site.nom} - ${widget.point.name} ($generated tickets)',
                              );
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.share, size: 18),
                          label: const Text('Partager', style: TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final file = await _generatePdfFromTickets(tickets,
                                  profileName: profileName, price: price);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('PDF: ${file.path.split('/').last}'),
                                    backgroundColor: AppTheme.success,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Erreur: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.picture_as_pdf, size: 18, color: Colors.white),
                          label: const Text('Télécharger',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
              Flexible(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  shrinkWrap: true,
                  itemCount: tickets.length,
                  itemBuilder: (_, i) {
                    final t = tickets[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                            child: Text('${i + 1}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t['code'] ?? '',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                                        letterSpacing: 1, color: isDark ? Colors.white : Colors.black87)),
                                Text('MDP: ${t['password'] ?? t['code']}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
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
        );
      },
    );
  }

  // ── UI Helpers ──

  Widget _dropdownContainer(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            size: 20,
            color: isDark ? Colors.white70 : Colors.grey.shade700),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final available = (_stats['available'] as num?)?.toInt() ?? 0;
    final used = (_stats['used'] as num?)?.toInt() ?? 0;
    final total = (_stats['total'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.point.name,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(widget.site.nom,
                            style: TextStyle(fontSize: 13, color: subColor)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: subColor, size: 20),
                    onPressed: () async {
                      final edited = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PointFormScreen(
                                siteId: widget.site.id,
                                point: widget.point)),
                      );
                      if (edited == true && mounted) _load();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon:
                        Icon(Icons.people_outline, color: subColor, size: 20),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  GerantsScreen(point: widget.point)));
                    },
                    style: IconButton.styleFrom(
                      backgroundColor:
                          isDark ? AppTheme.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.danger.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.wifi_off_rounded,
                                      size: 40, color: AppTheme.danger),
                                ),
                                const SizedBox(height: 16),
                                Text('Impossible de charger les données',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF1A1D21))),
                                const SizedBox(height: 8),
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: subColor)),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                                  label: const Text('Réessayer',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                  : RefreshIndicator(
                      color: AppTheme.primary,
                      onRefresh: _load,
                      child: Column(
                        children: [
                          // Stats cards
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _statCard(
                                    'Disponibles',
                                    available,
                                    AppTheme.success,
                                    Icons.confirmation_number_outlined,
                                    cardColor,
                                    textColor,
                                    subColor,
                                    isDark),
                                const SizedBox(width: 10),
                                _statCard(
                                    'Vendus',
                                    used,
                                    AppTheme.primary,
                                    Icons.sell_outlined,
                                    cardColor,
                                    textColor,
                                    subColor,
                                    isDark),
                                const SizedBox(width: 10),
                                _statCard(
                                    'Total',
                                    total,
                                    isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    Icons.inventory_2_outlined,
                                    cardColor,
                                    textColor,
                                    subColor,
                                    isDark),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Action buttons row
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 46,
                                    child: ElevatedButton.icon(
                                      onPressed: _showGenerateSheet,
                                      icon: const Icon(Icons.bolt,
                                          color: Colors.white, size: 18),
                                      label: const Text(
                                        'Générer',
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ),
                                if (available > 0) ...[
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    height: 46,
                                    child: OutlinedButton.icon(
                                      onPressed: _shareAvailableVouchersPdf,
                                      icon: const Icon(Icons.share, size: 16),
                                      label: const Text('PDF',
                                          style: TextStyle(fontSize: 13)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primary,
                                        side: BorderSide(
                                            color: AppTheme.primary
                                                .withValues(alpha: 0.4)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Tab bar
                          Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicator: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: subColor,
                              labelStyle: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              dividerColor: Colors.transparent,
                              padding: const EdgeInsets.all(4),
                              tabs: [
                                Tab(
                                    text:
                                        'Tickets (${_vouchers.length})'),
                                Tab(
                                    text:
                                        'Lots (${_batches.length})'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tab views
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildVouchersTab(isDark, cardColor,
                                    textColor, subColor),
                                _buildBatchesTab(isDark, cardColor,
                                    textColor, subColor),
                              ],
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

  // ── Vouchers Tab ──

  Widget _buildVouchersTab(
      bool isDark, Color cardColor, Color textColor, Color subColor) {
    if (_vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.confirmation_number_outlined,
                  size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 14),
            Text('Aucun ticket',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: subColor)),
            const SizedBox(height: 4),
            Text('Générez des tickets pour ce point',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _vouchers.length,
      itemBuilder: (_, i) =>
          _buildTicketRow(_vouchers[i], isDark, cardColor, textColor, subColor),
    );
  }

  // ── Batches Tab ──

  Widget _buildBatchesTab(
      bool isDark, Color cardColor, Color textColor, Color subColor) {
    if (_batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory_2_outlined,
                  size: 40, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 14),
            Text('Aucun lot',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: subColor)),
            const SizedBox(height: 4),
            Text('Les lots générés apparaîtront ici',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _batches.length,
      itemBuilder: (_, i) {
        final batch = _batches[i];
        final profileName = batch['profile_name'] ?? '';
        final qty = (batch['quantity'] as num?)?.toInt() ?? 0;
        final availableCount = (batch['available_count'] as num?)?.toInt() ?? 0;
        final usedCount = (batch['used_count'] as num?)?.toInt() ?? 0;
        final createdFmt = batch['created_fmt'] ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: profile + date
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(profileName,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary)),
                  ),
                  const Spacer(),
                  Text(createdFmt,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 10),

              // Stats row
              Row(
                children: [
                  _batchStat('Total', qty, textColor, subColor),
                  const SizedBox(width: 16),
                  _batchStat('Dispo', availableCount, AppTheme.success, subColor),
                  const SizedBox(width: 16),
                  _batchStat('Vendus', usedCount, AppTheme.primary, subColor),
                  const Spacer(),

                  // Share button
                  IconButton(
                    icon: const Icon(Icons.share, size: 18),
                    color: AppTheme.primary,
                    onPressed: () => _shareBatchPdf(batch),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: 'Partager PDF',
                  ),
                  const SizedBox(width: 6),
                  // Download button
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    color: AppTheme.primary,
                    onPressed: () => _downloadBatchPdf(batch),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.all(8),
                    ),
                    tooltip: 'Télécharger PDF',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _batchStat(String label, int value, Color valueColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: valueColor)),
        Text(label, style: TextStyle(fontSize: 10, color: labelColor)),
      ],
    );
  }

  // ── Shared Widgets ──

  Widget _statCard(String label, int value, Color accent, IconData icon,
      Color cardColor, Color textColor, Color subColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(height: 8),
            Text('$value',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: subColor),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketRow(Map<String, dynamic> t, bool isDark, Color cardColor,
      Color textColor, Color subColor) {
    final code = t['code'] ?? t['name'] ?? '';
    final profile = t['profile_name'] ?? t['profile'] ?? '';
    final status = t['status'] ?? 'available';
    final isAvailable = status == 'available';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isAvailable ? AppTheme.success : Colors.grey)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isAvailable ? Icons.confirmation_number : Icons.check_circle,
                color: isAvailable ? AppTheme.success : Colors.grey,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(code,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                          letterSpacing: 1),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(profile,
                      style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: (isAvailable ? AppTheme.success : Colors.grey)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isAvailable ? 'Disponible' : 'Vendu',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isAvailable ? AppTheme.success : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
