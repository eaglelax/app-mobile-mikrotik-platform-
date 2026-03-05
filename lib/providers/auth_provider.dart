import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AuthProvider with ChangeNotifier {
  final _authService = AuthService();
  User? _user;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get error => _error;

  bool hasFeature(String f) => _user?.hasFeature(f) ?? false;

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    await ApiClient().init();
    _user = await _authService.getSavedUser();

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erreur de connexion: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
