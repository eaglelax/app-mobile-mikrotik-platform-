import '../config/api_config.dart';
import 'api_client.dart';

class NotificationServiceApi {
  final _api = ApiClient();

  Future<Map<String, dynamic>> fetchAll({int page = 1}) async {
    return await _api.get(ApiConfig.notifications, {
      'page': page.toString(),
    });
  }

  Future<Map<String, dynamic>> markRead(int notificationId) async {
    return await _api.post(ApiConfig.notifications, {
      'action': 'mark_read',
      'notification_id': notificationId,
    });
  }

  Future<Map<String, dynamic>> markAllRead() async {
    return await _api.post(ApiConfig.notifications, {
      'action': 'mark_all_read',
    });
  }

  Future<int> fetchUnreadCount() async {
    final data = await _api.get(ApiConfig.notifications, {'count_only': '1'});
    return data['unread_count'] ?? 0;
  }
}
