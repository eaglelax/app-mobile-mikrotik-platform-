import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'cache_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  String? _bearerToken;
  String? _csrfToken;
  bool _isRefreshing = false;
  final _cache = CacheService();
  final _secureStorage = const FlutterSecureStorage();

  /// Static callback that the app shell can listen to for forced logout events.
  /// Set this from your AuthProvider or app initialization.
  static VoidCallback? onForceLogout;

  /// Stream controller for logout events (alternative to callback).
  static final StreamController<void> _logoutController =
      StreamController<void>.broadcast();
  static Stream<void> get onLogoutStream => _logoutController.stream;

  String get baseUrl => ApiConfig.baseUrl;

  Future<void> init() async {
    // Load tokens from secure storage
    _bearerToken = await _secureStorage.read(key: 'bearer_token');
    _csrfToken = await _secureStorage.read(key: 'csrf_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (_bearerToken != null) 'Authorization': 'Bearer $_bearerToken',
        if (_csrfToken != null) 'X-CSRF-Token': _csrfToken!,
      };

  /// Save login credentials for auto-re-login (secure storage)
  Future<void> saveCredentials(String email, String password) async {
    await _secureStorage.write(key: 'auth_email', value: email);
    await _secureStorage.write(key: 'auth_password', value: password);
  }

  /// Try to re-login with saved credentials
  Future<bool> _tryAutoRelogin() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final email = await _secureStorage.read(key: 'auth_email');
      final password = await _secureStorage.read(key: 'auth_password');
      if (email == null || password == null) return false;

      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.login}');
      final response = await http
          .post(uri,
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: {'email': email, 'password': password})
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['token'] != null) {
          setToken(data['token']);
          if (data['csrf_token'] != null) {
            setCsrfToken(data['csrf_token']);
          }
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Auto-relogin failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Handle 401 after relogin failure: clear tokens and trigger global logout.
  void _triggerForceLogout() {
    debugPrint('ApiClient: Force logout triggered (401 + relogin failed)');
    clearSession();
    onForceLogout?.call();
    _logoutController.add(null);
  }

  Future<Map<String, dynamic>> get(String endpoint,
      [Map<String, String>? params, Duration? timeout]) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (params != null) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params});
    }

    var response = await http
        .get(uri, headers: _headers)
        .timeout(timeout ?? ApiConfig.timeout);

    // Auto re-login on 401
    if (response.statusCode == 401) {
      if (await _tryAutoRelogin()) {
        response = await http
            .get(uri, headers: _headers)
            .timeout(timeout ?? ApiConfig.timeout);
      } else {
        _triggerForceLogout();
      }
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint,
      [Map<String, dynamic>? body, Duration? timeout]) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final payload = body ?? {};
    if (_csrfToken != null) {
      payload['csrf_token'] = _csrfToken;
    }
    final effectiveTimeout = timeout ?? ApiConfig.timeout;

    var response = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(effectiveTimeout);

    // Auto re-login on 401
    if (response.statusCode == 401) {
      if (await _tryAutoRelogin()) {
        response = await http
            .post(uri, headers: _headers, body: jsonEncode(payload))
            .timeout(effectiveTimeout);
      } else {
        _triggerForceLogout();
      }
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> postForm(
      String endpoint, Map<String, String> fields) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (_csrfToken != null) {
      fields['csrf_token'] = _csrfToken!;
    }

    var response = await http
        .post(uri,
            headers: {
              ..._headers,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: fields)
        .timeout(ApiConfig.timeout);

    // Auto re-login on 401
    if (response.statusCode == 401) {
      if (await _tryAutoRelogin()) {
        response = await http
            .post(uri,
                headers: {
                  ..._headers,
                  'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: fields)
            .timeout(ApiConfig.timeout);
      } else {
        _triggerForceLogout();
      }
    }

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw ApiException('Session expiree, veuillez vous reconnecter',
          statusCode: 401);
    }

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'data': data};
    } catch (_) {
      if (response.statusCode >= 400) {
        throw ApiException('Erreur serveur (${response.statusCode})',
            statusCode: response.statusCode);
      }
      return {'raw': response.body};
    }
  }

  Future<void> clearSession() async {
    _bearerToken = null;
    _csrfToken = null;
    _cache.clear();
    // Clear secure storage
    await _secureStorage.delete(key: 'bearer_token');
    await _secureStorage.delete(key: 'csrf_token');
    await _secureStorage.delete(key: 'auth_email');
    await _secureStorage.delete(key: 'auth_password');
  }

  void setToken(String token) {
    _bearerToken = token;
    _secureStorage.write(key: 'bearer_token', value: token);
  }

  void setCsrfToken(String token) {
    _csrfToken = token;
    _secureStorage.write(key: 'csrf_token', value: token);
  }

  /// GET with cache (stale-while-revalidate pattern).
  /// Returns cached/stale data immediately if available, refreshes in background.
  Future<Map<String, dynamic>> getCached(String endpoint,
      {Map<String, String>? params, Duration? ttl, Duration? timeout}) async {
    final cacheKey = _buildCacheKey(endpoint, params);

    // Fresh cache hit -> return immediately
    final cached = _cache.get(cacheKey);
    if (cached != null) return cached;

    // Stale data exists -> return it immediately, refresh in background
    final stale = _cache.getStale(cacheKey);
    if (stale != null) {
      // Fire-and-forget background refresh
      get(endpoint, params, timeout).then((data) {
        _cache.set(cacheKey, data, ttl);
      }).catchError((_) {}); // Ignore errors, stale data is better than nothing
      return stale;
    }

    // No cache at all -> fetch from network
    final data = await get(endpoint, params, timeout);
    _cache.set(cacheKey, data, ttl);
    return data;
  }

  /// Invalidate cache for a specific endpoint or prefix.
  void invalidateCache([String? prefix]) {
    if (prefix != null) {
      _cache.removeByPrefix(prefix);
    } else {
      _cache.clear();
    }
  }

  String _buildCacheKey(String endpoint, Map<String, String>? params) {
    if (params == null || params.isEmpty) return endpoint;
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '$endpoint?${sorted.map((e) => '${e.key}=${e.value}').join('&')}';
  }
}
