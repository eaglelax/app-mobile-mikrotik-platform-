import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../models/point.dart';
import '../../services/gerant_service.dart';

class GerantsScreen extends StatefulWidget {
  final Point point;
  const GerantsScreen({super.key, required this.point});

  @override
  State<GerantsScreen> createState() => _GerantsScreenState();
}

class _GerantsScreenState extends State<GerantsScreen> {
  final _service = GerantService();
  List<Map<String, dynamic>> _gerants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _gerants = await _service.fetchByPoint(widget.point.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  InputDecoration _styledInput(String label, {String? hint, bool isDark = false}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
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
        borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.danger, width: 1.8),
      ),
    );
  }

  Future<void> _createGerant() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Nouveau Gérant',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1D21),
            )),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1D21)),
                decoration: _styledInput('Nom (optionnel)', hint: 'Ex: Mamadou', isDark: isDark),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1D21)),
                decoration: _styledInput('Mot de passe', hint: 'Min. 4 caractères', isDark: isDark),
                validator: (v) =>
                    (v == null || v.length < 4) ? 'Min. 4 caractères' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, {
                  'name': nameCtrl.text.trim(),
                  'password': passCtrl.text,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (result == null) return;

    try {
      final res = await _service.create(
        pointId: widget.point.id,
        password: result['password'],
        name: result['name'],
      );
      if (res['success'] == true && mounted) {
        final gerant = res['gerant'];
        _showCredentials(gerant);
        _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Erreur'),
            backgroundColor: AppTheme.danger,
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

  void _showCredentials(Map<String, dynamic> gerant) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final username = gerant['username'] ?? gerant['email'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Gérant créé',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1D21),
            )),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identifiants de connexion:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF1A1D21),
                )),
            const SizedBox(height: 12),
            _credentialRow('Nom', gerant['name'] ?? '', isDark),
            _credentialRow('Username', username, isDark),
            _credentialRow('Point', gerant['point_name'] ?? widget.point.name, isDark),
            const SizedBox(height: 12),
            const Text(
              'Notez ces identifiants, le mot de passe ne sera plus visible.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Username: $username'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Username copié')),
              );
            },
            child: const Text('Copier username'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _credentialRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                )),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF1A1D21),
                )),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(Map<String, dynamic> gerant) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newPass = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset - ${gerant['name']}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1D21),
            )),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passCtrl,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1D21)),
            decoration: _styledInput('Nouveau mot de passe', hint: 'Min. 4 caractères', isDark: isDark),
            validator: (v) =>
                (v == null || v.length < 4) ? 'Min. 4 caractères' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, passCtrl.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Changer'),
          ),
        ],
      ),
    );

    if (newPass == null) return;

    try {
      final res = await _service.resetPassword(gerant['id'], newPass);
      if (res['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe mis à jour'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Erreur'),
            backgroundColor: AppTheme.danger,
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

  Future<void> _toggleStatus(Map<String, dynamic> gerant) async {
    final newStatus = gerant['status'] == 'active' ? 'inactive' : 'active';
    try {
      final res = await _service.update(gerant['id'], status: newStatus);
      if (res['success'] == true) _load();
    } catch (_) {}
  }

  Future<void> _deleteGerant(Map<String, dynamic> gerant) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer le gérant',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1D21),
            )),
        content: Text('Supprimer "${gerant['name']}" ?',
            style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await _service.delete(gerant['id']);
      if (res['success'] == true) {
        _load();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['error'] ?? 'Erreur'),
            backgroundColor: AppTheme.danger,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: textColor),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gérants', style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: textColor,
                        )),
                        Text(widget.point.name, style: TextStyle(fontSize: 13, color: subColor)),
                      ],
                    ),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _load,
                      icon: Icon(Icons.refresh, color: subColor),
                    ),
                  IconButton(
                    onPressed: _createGerant,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_add, size: 18, color: AppTheme.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: _loading && _gerants.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _gerants.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.grey : Colors.grey.shade300).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person_off, size: 48, color: Colors.grey.shade400),
                              ),
                              const SizedBox(height: 16),
                              Text('Aucun gérant pour ce point',
                                  style: TextStyle(color: subColor, fontSize: 15)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton.icon(
                                  onPressed: _createGerant,
                                  icon: const Icon(Icons.person_add, size: 18),
                                  label: const Text('Créer un gérant'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _gerants.length,
                            itemBuilder: (ctx, i) => _buildGerantCard(_gerants[i], isDark, textColor, subColor),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGerantCard(Map<String, dynamic> g, bool isDark, Color textColor, Color subColor) {
    final isActive = g['status'] == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isActive ? AppTheme.primary : Colors.grey).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person,
                color: isActive ? AppTheme.primary : Colors.grey, size: 22),
          ),
          title: Text(g['name'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
                fontSize: 15,
              )),
          subtitle: Text(
            g['email'] ?? '',
            style: TextStyle(fontSize: 12, color: subColor),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isActive ? AppTheme.success : Colors.grey).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Actif' : 'Inactif',
              style: TextStyle(
                color: isActive ? AppTheme.success : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          children: [
            if (g['last_login'] != null)
              _infoRow('Dernière connexion', g['last_login'], isDark),
            if (g['created_at'] != null)
              _infoRow('Créé le', g['created_at'], isDark),
            const SizedBox(height: 10),
            Row(
              children: [
                _actionChip(
                  Icons.lock_reset,
                  'Mot de passe',
                  AppTheme.primary,
                  isDark,
                  () => _resetPassword(g),
                ),
                const SizedBox(width: 8),
                _actionChip(
                  isActive ? Icons.block : Icons.check_circle,
                  isActive ? 'Désactiver' : 'Activer',
                  isActive ? Colors.orange : AppTheme.success,
                  isDark,
                  () => _toggleStatus(g),
                ),
                const SizedBox(width: 8),
                _actionChip(
                  Icons.delete_outline,
                  'Supprimer',
                  AppTheme.danger,
                  isDark,
                  () => _deleteGerant(g),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, bool isDark, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              )),
          Expanded(
            child: Text(value,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                )),
          ),
        ],
      ),
    );
  }
}
