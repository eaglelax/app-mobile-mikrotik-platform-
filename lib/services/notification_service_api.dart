import '../config/api_config.dart';
import 'api_client.dart';

class NotificationServiceApi {
  final _api = ApiClient();

  Future<Map<String, dynamic>> fetchAll({int page = 1}) async {
    return await _api.get(ApiConfig.notifications, {
      'action': 'list',
      'page': page.toString(),
    });
  }

  Future<Map<String, dynamic>> markRead(int notificationId) async {
    return await _api.post(ApiConfig.notifications, {
      'action': 'read',
      'id': notificationId,
    });
  }

  Future<Map<String, dynamic>> markAllRead() async {
    return await _api.post(ApiConfig.notifications, {
      'action': 'read_all',
    });
  }

  Future<int> fetchUnreadCount() async {
    final data = await _api.get(ApiConfig.notifications, {'action': 'count'});
    final d = data['data'];
    if (d is Map) return d['count'] ?? 0;
    return data['unread_count'] ?? 0;
  }
}
