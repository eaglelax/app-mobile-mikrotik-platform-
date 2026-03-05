import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/notification_provider.dart';
import '../../utils/formatters.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () => provider.markAllRead(),
              child: const Text('Tout lire'),
            ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_off,
                          size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Aucune notification'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.fetchAll(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: provider.notifications.length,
                    itemBuilder: (ctx, i) {
                      final n = provider.notifications[i];
                      final severityColor = switch (n.severity) {
                        'critical' || 'blocking' => AppTheme.danger,
                        'warning' => AppTheme.warning,
                        _ => AppTheme.info,
                      };
                      final severityIcon = switch (n.severity) {
                        'critical' || 'blocking' => Icons.error,
                        'warning' => Icons.warning,
                        _ => Icons.info_outline,
                      };

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        color: n.isRead ? null : AppTheme.darkSurface,
                        child: ListTile(
                          leading: Icon(severityIcon,
                              color: severityColor, size: 22),
                          title: Text(n.title,
                              style: TextStyle(
                                  fontWeight: n.isRead
                                      ? FontWeight.w400
                                      : FontWeight.w700,
                                  fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                              if (n.createdAt != null)
                                Text(Fmt.relative(n.createdAt!),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                            ],
                          ),
                          onTap: () {
                            if (!n.isRead) provider.markRead(n.id);
                          },
                          dense: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
