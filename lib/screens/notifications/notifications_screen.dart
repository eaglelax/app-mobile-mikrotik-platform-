import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/site.dart';
import '../../providers/notification_provider.dart';
import '../../providers/site_provider.dart';
import '../../utils/formatters.dart';
import '../sites/site_detail_screen.dart';
import '../reports/site_report_screen.dart';
import '../tickets/tickets_list_screen.dart';
import '../points/points_list_screen.dart';
import '../sales/sales_screen.dart';
import '../profiles/profiles_list_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationProvider>().fetchAll();
  }

  /// Resolve a Site object from its ID using SiteProvider
  Site? _findSite(int? siteId) {
    if (siteId == null) return null;
    final sites = context.read<SiteProvider>().sites;
    try {
      return sites.firstWhere((s) => s.id == siteId);
    } catch (_) {
      return null;
    }
  }

  /// Navigate based on actionUrl pattern
  void _handleNotificationTap(dynamic n, NotificationProvider provider) {
    // Mark as read
    if (!n.isRead) provider.markRead(n.id);

    final url = (n.actionUrl ?? '').toString().trim();
    if (url.isEmpty) return;

    // Parse actionUrl patterns:
    //   site/{id}          → SiteDetailScreen
    //   report/{siteId}    → SiteReportScreen
    //   tickets/{siteId}   → TicketsListScreen
    //   points/{siteId}    → PointsListScreen
    //   sales/{siteId}     → SalesScreen
    //   profiles/{siteId}  → ProfilesListScreen
    final parts = url.split('/');
    if (parts.length < 2) return;

    final route = parts[0];
    final id = int.tryParse(parts[1]);
    // Try route-level siteId, fallback to notification's siteId
    final site = _findSite(id) ?? _findSite(n.siteId);

    if (site == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Site introuvable'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    Widget? page;
    switch (route) {
      case 'site':
        page = SiteDetailScreen(site: site);
        break;
      case 'report':
      case 'reports':
        page = SiteReportScreen(site: site);
        break;
      case 'tickets':
      case 'ticket':
        page = TicketsListScreen(site: site);
        break;
      case 'points':
      case 'point':
        page = PointsListScreen(site: site);
        break;
      case 'sales':
      case 'sale':
        page = SalesScreen(site: site);
        break;
      case 'profiles':
      case 'profile':
        page = ProfilesListScreen(site: site);
        break;
    }

    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1D21);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: titleColor,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? AppTheme.darkSurface
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                  ),
                  if (provider.unreadCount > 0)
                    TextButton(
                      onPressed: () => provider.markAllRead(),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            AppTheme.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Tout lire',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.notifications.isEmpty
                      ? _buildEmptyState(isDark, subtitleColor)
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: () => provider.fetchAll(),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: provider.notifications.length,
                            itemBuilder: (ctx, i) {
                              final n = provider.notifications[i];
                              return _buildNotificationCard(
                                n,
                                provider,
                                isDark,
                                cardColor,
                                titleColor,
                                subtitleColor,
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

  Widget _buildEmptyState(bool isDark, Color subtitleColor) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurface
                  : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune notification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vous n\'avez pas encore de notifications',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    dynamic n,
    NotificationProvider provider,
    bool isDark,
    Color cardColor,
    Color titleColor,
    Color subtitleColor,
  ) {
    final severityColor = switch (n.severity) {
      'critical' || 'blocking' => AppTheme.danger,
      'warning' => AppTheme.warning,
      _ => AppTheme.info,
    };
    final severityIcon = switch (n.severity) {
      'critical' || 'blocking' => Icons.error_rounded,
      'warning' => Icons.warning_rounded,
      _ => Icons.info_outline_rounded,
    };

    final hasAction = (n.actionUrl ?? '').toString().trim().isNotEmpty;

    final unreadTint = !n.isRead
        ? (isDark
            ? AppTheme.primary.withValues(alpha: 0.06)
            : AppTheme.primary.withValues(alpha: 0.04))
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleNotificationTap(n, provider),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: !n.isRead
                  ? Border(
                      left: BorderSide(
                        color: severityColor,
                        width: 3,
                      ),
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: unreadTint,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Severity icon with colored circle
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      severityIcon,
                      color: severityColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: n.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8),
                                decoration: const BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (n.createdAt != null)
                              Text(
                                Fmt.relative(n.createdAt!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            if (hasAction) ...[
                              const Spacer(),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
