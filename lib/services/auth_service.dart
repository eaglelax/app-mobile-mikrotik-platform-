import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final _api = ApiClient();

  Future<User> login(String email, String password) async {
    final data = await _api.postForm('/api/auth/login.php', {
      'email': email,
      'password': password,
    });

    if (data['success'] == true && data['user'] != null) {
      final user = User.fromJson(data['user']);
      if (data['token'] != null) {
        _api.setToken(data['token']);
      }
      if (data['csrf_token'] != null) {
        _api.setCsrfToken(data['csrf_token']);
      }
      await _saveUser(user);
      await _api.saveCredentials(email, password);
      return user;
    }
    throw ApiException(data['error'] ?? 'Identifiants incorrects');
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout.php');
    } catch (_) {}
    await _api.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData == null) return null;
    try {
      return User.fromJson(jsonDecode(userData));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }
}
