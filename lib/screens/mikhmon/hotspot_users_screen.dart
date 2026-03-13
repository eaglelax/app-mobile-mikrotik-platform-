import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../services/mikhmon_service.dart';
import 'hotspot_user_add_screen.dart';

class HotspotUsersScreen extends StatefulWidget {
  final Site site;
  const HotspotUsersScreen({super.key, required this.site});

  @override
  State<HotspotUsersScreen> createState() => _HotspotUsersScreenState();
}

class _HotspotUsersScreenState extends State<HotspotUsersScreen> {
  final _service = MikhmonService();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _service.fetchHotspotUsers(widget.site.id);
      _users = (data['users'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _users;
    final s = _search.toLowerCase();
    return _users
        .where((u) =>
            (u['name'] ?? '').toString().toLowerCase().contains(s) ||
            (u['profile'] ?? '').toString().toLowerCase().contains(s))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final searchFill = isDark ? AppTheme.darkSurface : const Color(0xFFEEF0F5);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.05);

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) => HotspotUserAddScreen(site: widget.site)),
          );
          if (added == true) _load();
        },
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // -- Custom header --
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: textColor,
                    ),
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Utilisateurs Hotspot',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_users.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    icon: Icon(Icons.refresh_rounded,
                        size: 22, color: subtextColor),
                    splashRadius: 22,
                  ),
                ],
              ),
            ),

            // -- Capsule search bar --
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(
                    color: subtextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: subtextColor, size: 20),
                  filled: true,
                  fillColor: searchFill,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(50),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(fontSize: 14, color: textColor),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), () {
                    setState(() => _search = v);
                  });
                },
              ),
            ),

            // -- Content --
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Aucun utilisateur',
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppTheme.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final u = _filtered[i];
                              final disabled = u['disabled'] == 'true' ||
                                  u['disabled'] == true;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: shadowColor,
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: disabled
                                              ? (isDark
                                                  ? Colors.grey
                                                      .withValues(alpha: 0.2)
                                                  : Colors.grey
                                                      .withValues(alpha: 0.3))
                                              : AppTheme.primary
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          disabled
                                              ? Icons.block
                                              : Icons.person,
                                          color: disabled
                                              ? Colors.grey
                                              : AppTheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u['name'] ?? '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'Profil: ${u['profile'] ?? '-'}  ${u['uptime'] ?? ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: subtextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton(
                                        icon: Icon(Icons.more_vert,
                                            color: subtextColor, size: 20),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        color: cardColor,
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'remove',
                                            child: Text('Supprimer',
                                                style: TextStyle(
                                                    color: AppTheme.danger)),
                                          ),
                                        ],
                                        onSelected: (action) async {
                                          if (action == 'remove') {
                                            await _service.removeHotspotUser(
                                                widget.site.id,
                                                u['.id'] ?? '');
                                            _load();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
