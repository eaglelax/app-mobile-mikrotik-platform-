import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/mikhmon_service.dart';
import '../../utils/formatters.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GerantDashboardScreen extends StatefulWidget {
  const GerantDashboardScreen({super.key});

  @override
  State<GerantDashboardScreen> createState() => GerantDashboardScreenState();
}

class GerantDashboardScreenState extends State<GerantDashboardScreen> with WidgetsBindingObserver {
  final _mikhmon = MikhmonService();
  final _api = ApiClient();

  // Period filter
  String _period = 'today'; // today, week, month, custom
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTimeRange? _customRange;
  List<dynamic> _allSales = [];
  bool _hasLoaded = false;
  List<dynamic> _filteredSales = [];
  bool _refreshing = false;
  String? _error;
  Timer? _autoRefresh;

  // Month names in French
  static const _monthNames = [
    '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefresh?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load();
    }
  }

  /// Called from app shell when this tab becomes visible
  void refresh() => _load();

  int get _siteId => context.read<AuthProvider>().user?.siteId ?? 0;
  int get _pointId => context.read<AuthProvider>().user?.pointId ?? 0;

  Future<void> _load() async {
    setState(() => _refreshing = true);
    try {
      final siteId = _siteId;
      if (siteId == 0) {
        _error = 'Aucun site associé';
        setState(() => _refreshing = false);
        return;
      }

      final data = await _api.get('/api/sync-sales.php', {'site_id': siteId.toString()});

      // Filter sales by point_id for gérant
      final all = (data['sales'] as List?) ?? [];
      if (_pointId > 0) {
        _allSales = all
            .where((s) =>
                s['point_id'] != null &&
                int.tryParse(s['point_id'].toString()) == _pointId)
            .toList();
      } else {
        _allSales = all;
      }
      _applyPeriodFilter();
      _error = null;
      _hasLoaded = true;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _refreshing = false);
  }

  void _applyPeriodFilter() {
    final now = DateTime.now();
    final todayStr = _fmtDate(now);
    final weekAgo = _fmtDate(now.subtract(const Duration(days: 7)));

    _filteredSales = _allSales.where((s) {
      final date = (s['sale_date'] ?? '').toString();
      switch (_period) {
        case 'today':
          return date.startsWith(todayStr);
        case 'week':
          return date.compareTo(weekAgo) >= 0;
        case 'month':
          final mStart = '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-01';
          final nextMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
          final mEnd = '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';
          return date.compareTo(mStart) >= 0 && date.compareTo(mEnd) < 0;
        case 'custom':
          if (_customRange == null) return true;
          final startStr = _fmtDate(_customRange!.start);
          final endStr = _fmtDate(_customRange!.end.add(const Duration(days: 1)));
          return date.compareTo(startStr) >= 0 && date.compareTo(endStr) < 0;
        default:
          return true;
      }
    }).toList();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  num get _filteredTotal {
    num total = 0;
    for (final s in _filteredSales) {
      total += num.tryParse('${s['price'] ?? s['amount'] ?? 0}') ?? 0;
    }
    return total;
  }

  String get _periodLabel {
    switch (_period) {
      case 'today':
        return "Ventes du jour";
      case 'week':
        return "7 derniers jours";
      case 'month':
        final now = DateTime.now();
        if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) {
          return "Ventes de ce mois";
        }
        return "${_monthNames[_selectedMonth.month]} ${_selectedMonth.year}";
      case 'custom':
        if (_customRange != null) {
          return "${_customRange!.start.day}/${_customRange!.start.month} → ${_customRange!.end.day}/${_customRange!.end.month}";
        }
        return "Personnalisé";
      default:
        return "";
    }
  }

  void _setPeriod(String p) {
    if (p == 'month' && _period == 'month') {
      // Already on month — show month picker
      _showMonthPicker();
      return;
    }
    if (p == 'custom') {
      _showDateRangePicker();
      return;
    }
    setState(() {
      _period = p;
      if (p == 'month') {
        _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
      }
      _applyPeriodFilter();
    });
  }

  void _showMonthPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    // Generate last 12 months
    final months = List.generate(12, (i) {
      final d = DateTime(now.year, now.month - i);
      return DateTime(d.year, d.month);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
        final sub = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choisir un mois',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 12),
              ...months.map((m) {
                final isSelected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;
                final isCurrent = m.year == now.year && m.month == now.month;
                final label = '${_monthNames[m.month]} ${m.year}';

                return InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedMonth = m;
                      _period = 'month';
                      _applyPeriodFilter();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 20,
                          color: isSelected ? AppTheme.primary : sub,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.primary : textColor,
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'En cours',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.success),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDateRangePicker() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _customRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      locale: const Locale('fr', 'FR'),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(ctx).colorScheme.copyWith(
              primary: AppTheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _period = 'custom';
        _customRange = picked;
        _applyPeriodFilter();
      });
    }
  }

  Future<void> _showReactivateDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ctrl = TextEditingController();
    final siteId = _siteId;

    await showDialog(
      context: context,
      builder: (ctx) {
        bool loading = false;
        String? message;
        bool success = false;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restart_alt_rounded, size: 20, color: AppTheme.accent),
                ),
                const SizedBox(width: 12),
                Text('Réactiver ticket',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    )),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Entrez le code du ticket pour supprimer le MAC et permettre au client de se reconnecter.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Code ticket',
                    hintText: 'Ex: AB3K9Z',
                    labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurface : const Color(0xFFF5F6FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.8),
                    ),
                    prefixIcon: Icon(Icons.confirmation_number_outlined,
                        size: 20, color: isDark ? Colors.grey[400] : Colors.grey[500]),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: success
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error_outline,
                          size: 18,
                          color: success ? AppTheme.success : AppTheme.danger,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message!,
                            style: TextStyle(
                              fontSize: 13,
                              color: success ? AppTheme.success : AppTheme.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Fermer', style: TextStyle(color: Colors.grey.shade500)),
              ),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final code = ctrl.text.trim();
                        if (code.isEmpty) return;
                        setDialogState(() {
                          loading = true;
                          message = null;
                        });
                        try {
                          final res = await _mikhmon.clearMac(siteId, code);
                          setDialogState(() {
                            loading = false;
                            success = res['success'] == true;
                            message = success
                                ? 'Ticket réactivé avec succès'
                                : (res['error'] ?? 'Erreur');
                          });
                          if (success) ctrl.clear();
                        } catch (e) {
                          setDialogState(() {
                            loading = false;
                            success = false;
                            message = 'Erreur: $e';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Réactiver'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSaleDetail(dynamic sale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final code = sale['username'] ?? sale['code'] ?? sale['name'] ?? '';
    final profile = sale['profile'] ?? sale['profile_name'] ?? '';
    final price = num.tryParse('${sale['price'] ?? sale['amount'] ?? 0}') ?? 0;
    final date = sale['sale_date'] ?? '';
    final time = sale['sale_time'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // QR Code
            if (code.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: QrImageView(
                  data: 'Code: $code | Profil: $profile',
                  version: QrVersions.auto,
                  size: 160,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1A1D21)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1A1D21)),
                ),
              ),
            const SizedBox(height: 16),
            // Code
            Text(
              code,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            // Profile + price
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Fmt.currency(price),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.success),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Date + time
            Text(
              '$date${time.toString().isNotEmpty ? '  ·  $time' : ''}',
              style: TextStyle(fontSize: 13, color: subColor),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final sh = isDark
        ? <BoxShadow>[]
        : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))];

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mes Ventes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                        ),
                        Text(
                          user?.name ?? 'Gérant',
                          style: TextStyle(fontSize: 13, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  // Reactivate ticket button
                  GestureDetector(
                    onTap: _showReactivateDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restart_alt_rounded, size: 16, color: AppTheme.accent),
                          SizedBox(width: 5),
                          Text(
                            'Réactiver',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_refreshing)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: subColor),
                      ),
                    )
                  else
                    IconButton(
                      onPressed: _load,
                      icon: Icon(Icons.refresh_rounded, size: 22, color: subColor),
                    ),
                ],
              ),
            ),

            // Period filters — row 1: today, week, month, custom
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _chipBtn("Aujourd'hui", 'today', cardColor, textColor, subColor, sh),
                  const SizedBox(width: 6),
                  _chipBtn('7 jours', 'week', cardColor, textColor, subColor, sh),
                  const SizedBox(width: 6),
                  _chipBtn(
                    _period == 'month'
                        ? '${_monthNames[_selectedMonth.month].substring(0, 3)}.'
                        : 'Mois',
                    'month',
                    cardColor, textColor, subColor, sh,
                    icon: Icons.keyboard_arrow_down_rounded,
                  ),
                  const SizedBox(width: 6),
                  _chipBtn(
                    _period == 'custom' && _customRange != null
                        ? '${_customRange!.start.day}/${_customRange!.start.month}'
                        : 'Période',
                    'custom',
                    cardColor, textColor, subColor, sh,
                    icon: Icons.date_range_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: _error != null && !_hasLoaded
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: subColor)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _load,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Revenue hero card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _periodLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  Fmt.currency(_filteredTotal),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${_filteredSales.length} ventes',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Sales list header
                          Text(
                            'Dernières ventes',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (_filteredSales.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: sh,
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.receipt_long, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text('Aucune vente', style: TextStyle(color: subColor)),
                                ],
                              ),
                            )
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: sh,
                              ),
                              child: Column(
                                children: _filteredSales.asMap().entries.map((entry) {
                                  final i = entry.key;
                                  final s = entry.value;
                                  final isLast = i == _filteredSales.length - 1;
                                  return Column(
                                    children: [
                                      InkWell(
                                        onTap: () => _showSaleDetail(s),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36, height: 36,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.success.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.receipt, size: 18, color: AppTheme.success),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      s['profile'] ?? s['profile_name'] ?? '',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 14,
                                                        color: textColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${s['sale_date'] ?? ''}${(s['sale_time'] ?? '').toString().isNotEmpty ? '  ·  ${s['sale_time']}' : ''}',
                                                      style: TextStyle(fontSize: 12, color: subColor),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                Fmt.currency(num.tryParse(
                                                        '${s['price'] ?? s['amount'] ?? 0}') ??
                                                    0),
                                                style: const TextStyle(
                                                  color: AppTheme.success,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(Icons.chevron_right, size: 16, color: subColor),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Divider(
                                          height: 1,
                                          indent: 64,
                                          color: isDark ? AppTheme.darkBorder : Colors.grey.shade200,
                                        ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipBtn(String label, String value, Color card, Color text, Color sub, List<BoxShadow> sh, {IconData? icon}) {
    final selected = _period == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setPeriod(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : card,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))]
                : sh,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : sub,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 2),
                Icon(icon, size: 14, color: selected ? Colors.white : sub),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
