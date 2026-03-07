import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AuthProvider with ChangeNotifier {
  final _authService = AuthService();
  User? _user;
  bool _isLoading = true;
  String? _error;
  bool _pinVerified = false;
  bool _hasPin = false;
  bool _needsPinSetup = false;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get error => _error;
  bool get pinVerified => _pinVerified;
  bool get hasPin => _hasPin;
  bool get needsPinSetup => _needsPinSetup;

  bool hasFeature(String f) => _user?.hasFeature(f) ?? false;

  Future<void> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    await ApiClient().init();
    _user = await _authService.getSavedUser();

    // Check if user has a PIN set
    final prefs = await SharedPreferences.getInstance();
    _hasPin = prefs.getString('user_pin') != null;
    _pinVerified = false;

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);

      // After first login, check if PIN exists
      final prefs = await SharedPreferences.getInstance();
      _hasPin = prefs.getString('user_pin') != null;
      if (!_hasPin) {
        _needsPinSetup = true;
      }
      _pinVerified = true; // Just logged in with full credentials

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

  void onPinVerified() {
    _pinVerified = true;
    notifyListeners();
  }

  void onPinSetupDone() {
    _needsPinSetup = false;
    _hasPin = true;
    _pinVerified = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_pin');
    _user = null;
    _pinVerified = false;
    _hasPin = false;
    _needsPinSetup = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
