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
  String? _error;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider auth) {
    final wasAuth = _auth?.isAuthenticated ?? false;
    _auth = auth;
    if (auth.isAuthenticated && !wasAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => refreshUnreadCount());
    }
  }

  Future<void> refreshUnreadCount() async {
    if (_auth?.isAuthenticated != true) return;
    try {
      _unreadCount = await _service.fetchUnreadCount();
      _error = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Notification error: $e');
      _unreadCount = 0;
      _error = 'Erreur chargement notifications';
      notifyListeners();
    }
  }

  Future<void> fetchAll() async {
    _isLoading = true;
    _unreadCount = 0;
    notifyListeners();

    try {
      final data = await _service.fetchAll();
      final innerData = data['data'];
      final list = innerData is Map ? (innerData['items'] as List? ?? [])
                                    : (data['notifications'] as List? ?? []);
      _notifications = list.map((n) => AppNotification.fromJson(n as Map<String, dynamic>)).toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      _error = null;
    } catch (e) {
      debugPrint('Notification error: $e');
      _error = 'Erreur chargement notifications';
      _unreadCount = 0;
    }

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
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _service.markAllRead();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Notification error: $e');
    }
  }
}
