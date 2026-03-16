import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../services/gerant_service.dart';
import '../../services/hotspot_server_service.dart';
import '../../services/point_service_api.dart';

class PointFormScreen extends StatefulWidget {
  final int siteId;
  final Point? point; // null = create
  const PointFormScreen({super.key, required this.siteId, this.point});

  @override
  State<PointFormScreen> createState() => _PointFormScreenState();
}

class _PointFormScreenState extends State<PointFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = PointServiceApi();
  final _gerantService = GerantService();
  final _hsService = HotspotServerService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _contactNameCtrl;
  late final TextEditingController _contactPhoneCtrl;
  late final TextEditingController _gerantPasswordCtrl;
  String _type = 'vendeur';
  bool _isActive = true;
  bool _loading = false;
  bool _createGerant = false;
  List<Map<String, dynamic>> _gerants = [];
  bool _loadingGerants = false;
  List<Map<String, dynamic>> _hotspotServers = [];
  bool _loadingServers = false;
  int? _selectedServerId;

  bool get isEdit => widget.point != null;

  static const _types = [
    {'value': 'vendeur', 'label': 'Vendeur', 'icon': Icons.store_rounded, 'color': Color(0xFF3B82F6)},
    {'value': 'zone', 'label': 'Zone', 'icon': Icons.wifi_rounded, 'color': Color(0xFFF59E0B)},
    {'value': 'partenaire', 'label': 'Partenaire', 'icon': Icons.handshake_rounded, 'color': Color(0xFF8B5CF6)},
    {'value': 'lieu', 'label': 'Lieu', 'icon': Icons.place_rounded, 'color': Color(0xFF10B981)},
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.point;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _contactNameCtrl = TextEditingController(text: p?.contactName ?? '');
    _contactPhoneCtrl = TextEditingController(text: p?.contactPhone ?? '');
    _gerantPasswordCtrl = TextEditingController();
    _type = p?.type ?? 'vendeur';
    _isActive = p?.isActive ?? true;
    _selectedServerId = p?.hotspotServerId;
    if (isEdit) _loadGerants();
    _loadHotspotServers();
  }

  Future<void> _loadHotspotServers() async {
    setState(() => _loadingServers = true);
    try {
      _hotspotServers = await _hsService.fetchBySite(widget.siteId);
    } catch (_) {}
    if (mounted) setState(() => _loadingServers = false);
  }

  Future<void> _loadGerants() async {
    setState(() => _loadingGerants = true);
    try {
      _gerants = await _gerantService.fetchByPoint(widget.point!.id);
    } catch (_) {}
    if (mounted) setState(() => _loadingGerants = false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final data = {
        'site_id': widget.siteId,
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'description': _descCtrl.text.trim(),
        'contact_name': _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
        'is_active': _isActive,
        'hotspot_server_id': _selectedServerId,
      };

      final result = isEdit
          ? await _service.update(widget.point!.id, data)
          : await _service.create(data);

      if (mounted && result['success'] == true) {
        if (_createGerant && _gerantPasswordCtrl.text.trim().isNotEmpty) {
          final pointId = isEdit ? widget.point!.id : (result['id'] as int);
          try {
            final gr = await _gerantService.create(
              pointId: pointId,
              password: _gerantPasswordCtrl.text.trim(),
              name: _contactNameCtrl.text.trim().isNotEmpty
                  ? _contactNameCtrl.text.trim()
                  : null,
            );
            if (mounted && gr['success'] == true) {
              // Backend returns gerant info nested in 'gerant' key
              final gerantData = gr['gerant'] as Map<String, dynamic>? ?? {};
              await _showGerantCreated(
                gerantData['username'] ?? '',
                _gerantPasswordCtrl.text.trim(),
              );
            } else if (mounted) {
              final errMsg = gr['error'] ?? 'Erreur création gérant';
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Erreur gérant'),
                  content: Text('Point sauvegardé, mais erreur gérant:\n$errMsg'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              await showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Erreur gérant'),
                  content: Text('Point sauvegardé, mais erreur gérant:\n$e'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
          }
        }
        if (mounted) Navigator.pop(context, true);
      } else if (mounted) {
        if (result['success'] != true) {
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

  Future<void> _showGerantCreated(String username, String password) async {
    if (username.isEmpty) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compte gérant créé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Identifiants du gérant:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _copyRow('Utilisateur', username),
            const SizedBox(height: 8),
            _copyRow('Mot de passe', password),
            const SizedBox(height: 12),
            Text('Notez ces identifiants, le mot de passe ne sera plus visible.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  Widget _copyRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copié'), duration: const Duration(seconds: 1)),
            );
          },
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Future<void> _resetGerantPassword(Map<String, dynamic> gerant) async {
    final ctrl = TextEditingController();
    final newPwd = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset - ${gerant['name'] ?? gerant['username']}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nouveau mot de passe',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Valider')),
        ],
      ),
    );
    if (newPwd == null || newPwd.isEmpty) return;
    try {
      await _gerantService.resetPassword(gerant['id'] as int, newPwd);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Mot de passe réinitialisé'),
              backgroundColor: AppTheme.success),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // ─── Header ───
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEdit ? 'Modifier le point' : 'Nouveau point',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ─── Form ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Name field ───
                    _buildLabel('Nom *'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _nameCtrl,
                      hint: 'Nom du point de vente',
                      icon: Icons.badge_rounded,
                      validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                    ),

                    const SizedBox(height: 20),

                    // ─── Type selector ───
                    _buildLabel('Type'),
                    const SizedBox(height: 10),
                    Row(
                      children: _types.map((t) {
                        final value = t['value'] as String;
                        final label = t['label'] as String;
                        final icon = t['icon'] as IconData;
                        final color = t['color'] as Color;
                        final selected = _type == value;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () => setState(() => _type = value),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? color.withValues(alpha: 0.15)
                                      : (isDark ? AppTheme.darkCard : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected ? color : Colors.transparent,
                                    width: 1.5,
                                  ),
                                  boxShadow: isDark
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                ),
                                child: Column(
                                  children: [
                                    Icon(icon, color: selected ? color : Colors.grey.shade400, size: 22),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                        color: selected
                                            ? color
                                            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ─── Hotspot Server selector ───
                    _buildLabel('Serveur Hotspot'),
                    const SizedBox(height: 6),
                    if (_loadingServers)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_hotspotServers.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline, color: Colors.grey.shade400, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Aucun serveur hotspot. Synchronisez depuis le routeur.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              setState(() => _loadingServers = true);
                              try {
                                await _hsService.syncFromRouter(widget.siteId);
                                await _loadHotspotServers();
                              } catch (_) {
                                if (mounted) setState(() => _loadingServers = false);
                              }
                            },
                            child: const Icon(Icons.sync, size: 18, color: AppTheme.primary),
                          ),
                        ]),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _selectedServerId,
                            hint: Text('Aucun (pas de filtrage serveur)',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                            dropdownColor: isDark ? AppTheme.darkCard : Colors.white,
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Aucun',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: isDark ? Colors.white70 : Colors.grey.shade600)),
                              ),
                              ..._hotspotServers.map((s) {
                                final id = s['id'] is int ? s['id'] as int : int.tryParse(s['id'].toString()) ?? 0;
                                final name = s['name'] ?? '';
                                final iface = s['interface'] ?? '';
                                return DropdownMenuItem<int?>(
                                  value: id,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.router, size: 16, color: AppTheme.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          iface.isNotEmpty ? '$name ($iface)' : name,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black87),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) => setState(() => _selectedServerId = val),
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ─── Description ───
                    _buildLabel('Description'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _descCtrl,
                      hint: 'Description (optionnel)',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),

                    const SizedBox(height: 20),

                    // ─── Contact section ───
                    _buildLabel('Contact'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _contactNameCtrl,
                      hint: 'Nom du contact',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 10),
                    _buildTextField(
                      controller: _contactPhoneCtrl,
                      hint: 'Telephone',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),

                    const SizedBox(height: 20),

                    // ─── Active toggle ───
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_isActive ? AppTheme.success : Colors.grey).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: _isActive ? AppTheme.success : Colors.grey,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Statut',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF1A1D21),
                                  ),
                                ),
                                Text(
                                  _isActive ? 'Point actif' : 'Point inactif',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            activeThumbColor: AppTheme.success,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── Gerant section ───
                    _buildLabel('Compte Gérant'),
                    const SizedBox(height: 10),

                    if (isEdit && _loadingGerants)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),

                    if (isEdit && !_loadingGerants && _gerants.isNotEmpty)
                      ..._gerants.map((g) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (g['status'] == 'active'
                                            ? AppTheme.success
                                            : Colors.grey)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.person_rounded,
                                      color: g['status'] == 'active'
                                          ? AppTheme.success
                                          : Colors.grey,
                                      size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(g['username'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF1A1D21),
                                          )),
                                      if (g['name'] != null && g['name'] != '')
                                        Text(g['name'],
                                            style: TextStyle(
                                                fontSize: 12, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.lock_reset_rounded, size: 20),
                                  tooltip: 'Reset mot de passe',
                                  onPressed: () => _resetGerantPassword(g),
                                ),
                              ],
                            ),
                          )),

                    if (isEdit && !_loadingGerants && _gerants.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text('Aucun gérant pour ce point.',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      ),

                    if (!isEdit || _gerants.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person_add_rounded,
                                  color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Créer un compte gérant',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                                    ),
                                  ),
                                  Text(
                                    'Permet de gérer ce point',
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _createGerant,
                              onChanged: (v) => setState(() => _createGerant = v),
                              activeThumbColor: AppTheme.primary,
                            ),
                          ],
                        ),
                      ),
                      if (_createGerant) ...[
                        const SizedBox(height: 10),
                        _buildTextField(
                          controller: _gerantPasswordCtrl,
                          hint: 'Mot de passe du gérant (min 4 car.)',
                          icon: Icons.lock_rounded,
                          validator: _createGerant
                              ? (v) => v == null || v.length < 4
                                  ? 'Min 4 caractères'
                                  : null
                              : null,
                        ),
                      ],
                    ],

                    const SizedBox(height: 30),

                    // ─── Submit button ───
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                            : Text(
                                isEdit ? 'Enregistrer' : 'Creer le point',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: isDark ? Colors.white : const Color(0xFF1A1D21),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        filled: true,
        fillColor: isDark ? AppTheme.darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _gerantPasswordCtrl.dispose();
    super.dispose();
  }
}
