import 'package:flutter/material.dart';
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
        final generated = result['generated'] ?? qty;
        final synced = result['synced'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$generated ticket(s) générés, $synced synchronisés'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
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
}
