import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service_api.dart';

class NotificationProvider with ChangeNotifier {
  final _service = NotificationServiceApi();
  AuthProvider? _auth;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    if (auth.isAuthenticated) {
      refreshUnreadCount();
    }
  }

  Future<void> refreshUnreadCount() async {
    if (_auth?.isAuthenticated != true) return;
    try {
      _unreadCount = await _service.fetchUnreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _service.fetchAll();
      final innerData = data['data'];
      final list = innerData is Map ? (innerData['items'] as List? ?? [])
                                    : (data['notifications'] as List? ?? []);
      _notifications = list.map((n) => AppNotification.fromJson(n as Map<String, dynamic>)).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markRead(int id) async {
    try {
      await _service.markRead(id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1 && !_notifications[idx].isRead) {
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _service.markAllRead();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }
}
