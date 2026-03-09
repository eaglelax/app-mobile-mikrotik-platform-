import '../config/api_config.dart';
import 'api_client.dart';

class GerantService {
  final _api = ApiClient();

  Future<List<Map<String, dynamic>>> fetchBySite(int siteId) async {
    final data = await _api.get(ApiConfig.gerants, {
      'site_id': siteId.toString(),
    });
    final list = data['gerants'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchByPoint(int pointId) async {
    final data = await _api.get(ApiConfig.gerants, {
      'point_id': pointId.toString(),
    });
    final list = data['gerants'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create({
    required int pointId,
    required String password,
    String? name,
  }) async {
    return await _api.post(ApiConfig.gerants, {
      'action': 'create',
      'point_id': pointId,
      'password': password,
      if (name != null && name.isNotEmpty) 'name': name,
    });
  }

  Future<Map<String, dynamic>> update(int gerantId, {String? name, String? status}) async {
    return await _api.post(ApiConfig.gerants, {
      'action': 'update',
      'gerant_id': gerantId,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
    });
  }

  Future<Map<String, dynamic>> resetPassword(int gerantId, String newPassword) async {
    return await _api.post(ApiConfig.gerants, {
      'action': 'reset_password',
      'gerant_id': gerantId,
      'password': newPassword,
    });
  }

  Future<Map<String, dynamic>> delete(int gerantId) async {
    return await _api.post(ApiConfig.gerants, {
      'action': 'delete',
      'gerant_id': gerantId,
    });
  }
}
