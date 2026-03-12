import '../config/api_config.dart';
import 'api_client.dart';

class HotspotServerService {
  final _api = ApiClient();

  /// Fetch hotspot servers for a site (from local DB cache)
  Future<List<Map<String, dynamic>>> fetchBySite(int siteId) async {
    final data = await _api.get(ApiConfig.hotspotServers, {
      'site_id': siteId.toString(),
    });
    final list = data['servers'] as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Sync hotspot servers from router (triggers router connection)
  Future<Map<String, dynamic>> syncFromRouter(int siteId) async {
    return await _api.post(ApiConfig.hotspotServers, {
      'site_id': siteId,
    });
  }
}
