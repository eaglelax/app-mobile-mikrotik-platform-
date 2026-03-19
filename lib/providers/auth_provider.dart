import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';

class AuthProvider with ChangeNotifier {
  final _authService = AuthService();
  final _secureStorage = const FlutterSecureStorage();
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

    // Check if user has a PIN set (stored in secure storage)
    final pin = await _secureStorage.read(key: 'user_pin');
    _hasPin = pin != null;
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
      final pin = await _secureStorage.read(key: 'user_pin');
      _hasPin = pin != null;
      if (!_hasPin) {
        _needsPinSetup = true;
      }
      _pinVerified = true; // Just logged in with full credentials

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _user = null;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Erreur de connexion: $e';
      _user = null;
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
    // Clear all secure storage (PIN, tokens, credentials)
    await _secureStorage.delete(key: 'user_pin');
    await _secureStorage.delete(key: 'bearer_token');
    await _secureStorage.delete(key: 'csrf_token');
    await _secureStorage.delete(key: 'auth_email');
    await _secureStorage.delete(key: 'auth_password');
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
