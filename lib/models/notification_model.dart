class AppNotification {
  final int id;
  final int? siteId;
  final String type;
  final String severity;
  final String title;
  final String message;
  final String? actionUrl;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification({
    required this.id,
    this.siteId,
    required this.type,
    this.severity = 'info',
    required this.title,
    required this.message,
    this.actionUrl,
    this.isRead = false,
    this.createdAt,
  });

  bool get isCritical => severity == 'critical' || severity == 'blocking';

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] is int
            ? json['id']
            : int.tryParse(json['id'].toString()) ?? 0,
        siteId: json['site_id'] != null
            ? (json['site_id'] is int
                ? json['site_id']
                : int.tryParse(json['site_id'].toString()))
            : null,
        type: json['type'] ?? '',
        severity: json['severity'] ?? 'info',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        actionUrl: json['action_url'],
        isRead: json['read_at'] != null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'])
            : null,
      );
}
