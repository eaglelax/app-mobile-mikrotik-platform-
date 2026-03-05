import '../config/api_config.dart';
import '../models/point.dart';
import 'api_client.dart';

class PointServiceApi {
  final _api = ApiClient();

  Future<List<Point>> fetchBySite(int siteId) async {
    final data = await _api.get(ApiConfig.points, {
      'site_id': siteId.toString(),
    });
    final list = data['data'] as List? ?? data['points'] as List? ?? [];
    return list.map((p) => Point.fromJson(p)).toList();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> pointData) async {
    return await _api.post(ApiConfig.points, {
      'action': 'create',
      ...pointData,
    });
  }

  Future<Map<String, dynamic>> update(
      int pointId, Map<String, dynamic> pointData) async {
    return await _api.post(ApiConfig.points, {
      'action': 'update',
      'id': pointId,
      ...pointData,
    });
  }

  Future<Map<String, dynamic>> delete(int pointId) async {
    return await _api.post(ApiConfig.points, {
      'action': 'delete',
      'id': pointId,
    });
  }
}
