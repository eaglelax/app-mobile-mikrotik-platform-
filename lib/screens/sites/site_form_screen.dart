import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/site_provider.dart';
import '../../services/site_service.dart';
import '../../services/tunnel_service.dart';
import '../../utils/constants.dart';

class SiteFormScreen extends StatefulWidget {
  final Site? site; // null = create, non-null = edit
  const SiteFormScreen({super.key, this.site});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = SiteService();
  final _tunnelService = TunnelService();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _userCtrl;
  late final TextEditingController _passCtrl;
  String _typeActivite = 'other';
  String _currency = 'XOF';
  bool _loading = false;

  // Tunnel association
  List<Map<String, dynamic>> _availableTunnels = [];
  int? _selectedTunnelId;
  bool _loadingTunnels = true;

  bool get isEdit => widget.site != null;

  @override
  void initState() {
    super.initState();
    final s = widget.site;
    _nomCtrl = TextEditingController(text: s?.nom ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _ipCtrl = TextEditingController(text: s?.routerIp ?? '');
    _portCtrl = TextEditingController(text: '${s?.routerPort ?? 8728}');
    _userCtrl = TextEditingController(text: s?.routerUser ?? 'admin');
    _passCtrl = TextEditingController(text: s?.routerPassword ?? '');
    _typeActivite = s?.typeActivite ?? 'other';
    _currency = s?.currency ?? 'XOF';
    _loadTunnels();
  }

  Future<void> _loadTunnels() async {
    try {
      final data = await _tunnelService.fetchAll();
      final tunnels = (data['tunnels'] ?? data['peers'] ?? []) as List;
      if (mounted) {
        setState(() {
          // Show unlinked tunnels + tunnel already linked to this site (for edit)
          _availableTunnels = tunnels.cast<Map<String, dynamic>>().where((t) {
            final siteId = t['site_id'];
            return siteId == null || (isEdit && siteId.toString() == widget.site!.id.toString());
          }).toList();
          // Pre-select tunnel if editing and site has one
          if (isEdit) {
            for (final t in tunnels) {
              if (t['site_id']?.toString() == widget.site!.id.toString()) {
                _selectedTunnelId = int.tryParse(t['id'].toString());
                break;
              }
            }
          }
          _loadingTunnels = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTunnels = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final data = {
        'nom': _nomCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'router_ip': _ipCtrl.text.trim(),
        'router_port': int.tryParse(_portCtrl.text) ?? 8728,
        'router_user': _userCtrl.text.trim(),
        'router_password': _passCtrl.text,
        'type_activite': _typeActivite,
        'currency': _currency,
        if (isEdit) 'site_id': widget.site!.id,
      };

      final result = await _service.createSite(data);
      if (mounted) {
        if (result['success'] == true) {
          // Associate tunnel if selected
          final siteId = result['site_id'] ?? (isEdit ? widget.site!.id : null);
          if (_selectedTunnelId != null && siteId != null) {
            try {
              await _tunnelService.associate(_selectedTunnelId!, int.parse(siteId.toString()));
            } catch (_) {}
          }
          context.read<SiteProvider>().fetchSites();
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isEdit ? 'Site modifié' : 'Site créé')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['error'] ?? 'Erreur'),
                backgroundColor: AppTheme.danger),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  InputDecoration _inputDecoration(String label, {String? hint, bool isDark = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: isDark ? Colors.grey[600] : Colors.grey[400],
      ),
      filled: true,
      fillColor: isDark ? AppTheme.darkCard : Colors.white,
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.danger, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: textColor,
                      size: 22,
                    ),
                    splashRadius: 24,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEdit ? 'Modifier le site' : 'Nouveau site',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),

                      // Site info section
                      _SectionContainer(
                        isDark: isDark,
                        title: 'Informations du site',
                        children: [
                          TextFormField(
                            controller: _nomCtrl,
                            decoration: _inputDecoration('Nom du site *', isDark: isDark),
                            style: TextStyle(color: textColor),
                            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descCtrl,
                            decoration: _inputDecoration('Description', isDark: isDark),
                            style: TextStyle(color: textColor),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _typeActivite,
                            decoration: _inputDecoration("Type d'activité", isDark: isDark),
                            dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                            style: TextStyle(color: textColor, fontSize: 16),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            items: AppConstants.siteActivities.entries
                                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                .toList(),
                            onChanged: (v) => setState(() => _typeActivite = v ?? 'other'),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: _currency,
                            decoration: _inputDecoration('Devise', isDark: isDark),
                            dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                            style: TextStyle(color: textColor, fontSize: 16),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            items: const [
                              DropdownMenuItem(value: 'XOF', child: Text('XOF (FCFA)')),
                              DropdownMenuItem(value: 'XAF', child: Text('XAF (FCFA)')),
                              DropdownMenuItem(value: 'USD', child: Text('USD')),
                              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                            ],
                            onChanged: (v) => setState(() => _currency = v ?? 'XOF'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Router connection section
                      _SectionContainer(
                        isDark: isDark,
                        title: 'Connexion routeur',
                        children: [
                          TextFormField(
                            controller: _ipCtrl,
                            decoration: _inputDecoration('IP Routeur *', hint: '192.168.1.1', isDark: isDark),
                            style: TextStyle(color: textColor),
                            validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _portCtrl,
                                  decoration: _inputDecoration('Port API', isDark: isDark),
                                  style: TextStyle(color: textColor),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _userCtrl,
                                  decoration: _inputDecoration('Utilisateur', isDark: isDark),
                                  style: TextStyle(color: textColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passCtrl,
                            decoration: _inputDecoration('Mot de passe routeur', isDark: isDark),
                            style: TextStyle(color: textColor),
                            obscureText: true,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Tunnel VPN section
                      _SectionContainer(
                        isDark: isDark,
                        title: 'Tunnel VPN (optionnel)',
                        children: [
                          if (_loadingTunnels)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            ))
                          else if (_availableTunnels.isEmpty)
                            Text('Aucun tunnel disponible', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]))
                          else
                            DropdownButtonFormField<int>(
                              value: _selectedTunnelId,
                              decoration: _inputDecoration('Associer un tunnel', isDark: isDark),
                              dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                              style: TextStyle(color: textColor, fontSize: 16),
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              items: [
                                DropdownMenuItem<int>(value: null, child: Text('Aucun', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
                                ..._availableTunnels.map((t) {
                                  final id = int.tryParse(t['id'].toString()) ?? 0;
                                  final label = t['tunnel_label'] ?? t['tunnel_name'] ?? 'Tunnel #$id';
                                  final vpnIp = t['vpn_ip'] ?? '';
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text('$label ($vpnIp)', overflow: TextOverflow.ellipsis),
                                  );
                                }),
                              ],
                              onChanged: (v) => setState(() => _selectedTunnelId = v),
                            ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.5),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(isEdit ? 'Enregistrer' : 'Créer le site'),
                        ),
                      ),

                      const SizedBox(height: 24),
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

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}

class _SectionContainer extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<Widget> children;

  const _SectionContainer({
    required this.isDark,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
