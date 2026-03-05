import 'package:flutter/material.dart';
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
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchProfiles(widget.site.id);
      _profiles = (data['profiles'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generate() async {
    if (_selectedProfile == null) return;
    setState(() => _generating = true);

    try {
      _result = await _service.generateVouchers(widget.site.id, {
        'profile': _selectedProfile,
        'quantity': _quantity,
      });
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }

    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quick Print'),
            Text(widget.site.nom,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
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
                  // Profile selector
                  const Text('Profil',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProfile,
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

                  // Quantity
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
                              color:
                                  _quantity == q ? Colors.white : null,
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
                    label: Text(
                        _generating ? 'Génération...' : 'Générer $_quantity tickets'),
                  ),

                  // Result
                  if (_result != null && _result!['success'] == true) ...[
                    const SizedBox(height: 24),
                    Card(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle,
                                color: AppTheme.success, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              '${_result!['generated'] ?? _quantity} tickets générés',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
