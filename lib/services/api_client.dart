import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

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

  String? _sessionCookie;
  String? _csrfToken;

  String get baseUrl => ApiConfig.baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionCookie = prefs.getString('session_cookie');
    _csrfToken = prefs.getString('csrf_token');
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        if (_sessionCookie != null) 'Cookie': _sessionCookie!,
        if (_csrfToken != null) 'X-CSRF-Token': _csrfToken!,
      };

  Future<void> _saveCookies(http.Response response) async {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      // Extract PHPSESSID
      final match = RegExp(r'PHPSESSID=([^;]+)').firstMatch(setCookie);
      if (match != null) {
        _sessionCookie = 'PHPSESSID=${match.group(1)}';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_cookie', _sessionCookie!);
      }
    }
  }

  Future<Map<String, dynamic>> get(String endpoint,
      [Map<String, String>? params]) async {
    var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (params != null) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...params});
    }

    final response = await http
        .get(uri, headers: _headers)
        .timeout(ApiConfig.timeout);

    await _saveCookies(response);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(String endpoint,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final payload = body ?? {};
    if (_csrfToken != null) {
      payload['csrf_token'] = _csrfToken;
    }

    final response = await http
        .post(uri, headers: _headers, body: jsonEncode(payload))
        .timeout(ApiConfig.timeout);

    await _saveCookies(response);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> postForm(
      String endpoint, Map<String, String> fields) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    if (_csrfToken != null) {
      fields['csrf_token'] = _csrfToken!;
    }

    final response = await http
        .post(uri,
            headers: {
              ..._headers,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: fields)
        .timeout(ApiConfig.timeout);

    await _saveCookies(response);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      throw ApiException('Session expirée, veuillez vous reconnecter',
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
    _sessionCookie = null;
    _csrfToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    await prefs.remove('csrf_token');
  }

  void setCsrfToken(String token) {
    _csrfToken = token;
    SharedPreferences.getInstance()
        .then((p) => p.setString('csrf_token', token));
  }
}
