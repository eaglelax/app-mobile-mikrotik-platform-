import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/pdf_ticket_builder.dart';
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
  final _qtyController = TextEditingController(text: '10');

  List<Map<String, dynamic>> _profiles = [];
  final Set<String> _selectedProfiles = {};
  int _quantity = 10;
  bool _loading = true;
  bool _generating = false;

  // Existing generated tickets from hotspot
  List<Map<String, dynamic>> _existingTickets = [];
  bool _loadingTickets = false;

  // Result after generation
  List<Map<String, dynamic>>? _generatedTickets;
  int _synced = 0;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _loadExistingTickets();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
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

  Future<void> _loadExistingTickets() async {
    setState(() => _loadingTickets = true);
    try {
      final data = await _service.fetchHotspotUsers(widget.site.id);
      final users = (data['users'] as List? ?? []).cast<Map<String, dynamic>>();
      // Filter unsold vouchers (those not yet used)
      _existingTickets = users.where((u) {
        final uptime = u['uptime'] ?? '';
        return uptime == '' || uptime == '0s' || uptime == '00:00:00';
      }).toList();
    } catch (_) {}
    if (mounted) setState(() => _loadingTickets = false);
  }

  void _setQuantity(int q) {
    setState(() {
      _quantity = q;
      _qtyController.text = '$q';
    });
  }

  Future<void> _generate() async {
    if (_selectedProfiles.isEmpty) return;
    setState(() => _generating = true);

    try {
      // Launch generation for all selected profiles in parallel
      final futures = _selectedProfiles.map((profileName) {
        return _service.generateVouchers(widget.site.id, {
          'profile_name': profileName,
          'quantity': _quantity,
        });
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
            backgroundColor: isTimeout ? Colors.orange : AppTheme.danger,
            duration: Duration(seconds: isTimeout ? 6 : 4),
          ),
        );
        setState(() => _generating = false);
      }
    }
  }

  Future<File> _generatePdf(List<Map<String, dynamic>> tickets) async {
    return generateTicketsPdf(
      tickets: tickets,
      siteName: widget.site.nom,
    );
  }

  Future<void> _sharePdf(List<Map<String, dynamic>> tickets) async {
    try {
      final file = await _generatePdf(tickets);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Tickets ${widget.site.nom} - ${tickets.length} tickets',
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
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final shadow = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quick Print', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                        Text(widget.site.nom, style: TextStyle(fontSize: 13, color: subtitleColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // ── Profile Grid Selector (multi-select) ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Profils', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subtitleColor)),
                                  const Spacer(),
                                  if (_selectedProfiles.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => setState(() => _selectedProfiles.clear()),
                                      child: const Text('Tout décocher', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
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
                                            ? AppTheme.primary.withValues(alpha: isDark ? 0.3 : 0.12)
                                            : (isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA)),
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
                                              color: selected ? AppTheme.primary : (isDark ? Colors.white70 : Colors.black87),
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (price != null && price > 0)
                                            Text(
                                              '${price.toStringAsFixed(0)}F',
                                              style: TextStyle(fontSize: 10, color: subtitleColor),
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
                                  style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Quantity ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quantité', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: subtitleColor)),
                              const SizedBox(height: 10),
                              // Input field
                              TextFormField(
                                controller: _qtyController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primary, width: 1.5)),
                                  hintText: 'Nombre de tickets',
                                  hintStyle: TextStyle(color: subtitleColor, fontSize: 14, fontWeight: FontWeight.w400),
                                ),
                                onChanged: (v) {
                                  final n = int.tryParse(v);
                                  if (n != null && n > 0) setState(() => _quantity = n);
                                },
                              ),
                              const SizedBox(height: 12),
                              // Quick chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [5, 10, 20, 50, 100, 500, 1000].map((q) {
                                  final selected = _quantity == q;
                                  return GestureDetector(
                                    onTap: () => _setQuantity(q),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: selected ? AppTheme.primary : (isDark ? AppTheme.darkBg : const Color(0xFFF0F1F5)),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$q',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : textColor,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Generate Button ──
                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _generating || _selectedProfiles.isEmpty ? null : _generate,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: isDark ? AppTheme.darkCard : const Color(0xFFD0D5DD),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _generating
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                      SizedBox(width: 10),
                                      Text('Génération...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.print, size: 20),
                                      const SizedBox(width: 10),
                                      Text('Générer $_quantity tickets', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── Existing Tickets List ──
                        Row(
                          children: [
                            Text('Tickets en stock', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
                            const SizedBox(width: 8),
                            if (!_loadingTickets)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_existingTickets.length}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                ),
                              ),
                            const Spacer(),
                            if (_existingTickets.isNotEmpty)
                              GestureDetector(
                                onTap: () => _sharePdf(_existingTickets),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.print, size: 14, color: AppTheme.primary),
                                      SizedBox(width: 4),
                                      Text('Imprimer tout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_loadingTickets)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else if (_existingTickets.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 40, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text('Aucun ticket en stock', style: TextStyle(color: subtitleColor, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text('Générez des tickets ci-dessus', style: TextStyle(color: subtitleColor, fontSize: 12)),
                              ],
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _existingTickets.length,
                              separatorBuilder: (_, __) => Padding(
                                padding: const EdgeInsets.only(left: 56),
                                child: Divider(height: 1, color: dividerColor),
                              ),
                              itemBuilder: (ctx, i) {
                                final t = _existingTickets[i];
                                final name = t['name'] ?? '';
                                final profile = t['profile'] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 0.5),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(profile, style: TextStyle(fontSize: 12, color: subtitleColor)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final dividerColor = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final shadow = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

    final tickets = _generatedTickets!;
    final profile = tickets.isNotEmpty ? tickets[0]['profile'] ?? '' : '';
    final price = tickets.isNotEmpty ? tickets[0]['price'] : null;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Tickets générés', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
                  ),
                ],
              ),
            ),

            // Success banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle, color: AppTheme.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${tickets.length} tickets générés', style: TextStyle(fontWeight: FontWeight.w700, color: textColor, fontSize: 15)),
                        Text('$_synced synchronisés  ·  $profile${price != null ? '  ·  $price FCFA' : ''}', style: TextStyle(fontSize: 12, color: subtitleColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _sharePdf(tickets),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Partager'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                            await _generatePdf(tickets);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('PDF sauvegardé'), backgroundColor: AppTheme.success),
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
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Télécharger'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Ticket list
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), boxShadow: shadow),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Divider(height: 1, color: dividerColor),
                  ),
                  itemBuilder: (ctx, i) {
                    final t = tickets[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['code'] ?? '',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 1),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'MDP: ${t['password'] ?? t['code']}',
                                  style: TextStyle(fontSize: 12, color: subtitleColor),
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
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
