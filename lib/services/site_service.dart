import '../models/site.dart';
import 'api_client.dart';

class SiteService {
  final _api = ApiClient();

  Future<List<Site>> fetchAll() async {
    final data = await _api.getCached('/api/sites-list.php',
        ttl: const Duration(seconds: 30));
    final sites = data['sites'] as List? ?? [];
    return sites.map((s) => Site.fromJson(s)).toList();
  }

  Future<Map<String, dynamic>> fetchStats(int siteId, {bool forceRefresh = false}) async {
    if (forceRefresh) {
      _api.invalidateCache('/api/site-stats.php');
    }
    return await _api.getCached('/api/site-stats.php',
        params: {'site_id': siteId.toString()},
        ttl: const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> testConnection(int siteId) async {
    return await _api
        .post('/api/router-test.php', {'action': 'test_site', 'site_id': siteId});
  }

  Future<Map<String, dynamic>> createSite(Map<String, dynamic> data) async {
    final result = await _api.post('/api/sites-list.php', data);
    _api.invalidateCache('/api/sites-list');
    return result;
  }

  Future<Map<String, dynamic>> updateSite(int siteId, Map<String, dynamic> fields) async {
    final result = await _api.post('/api/sites-list.php', {
      'action': 'update',
      'site_id': siteId,
      ...fields,
    });
    _api.invalidateCache('/api/sites-list');
    _api.invalidateCache('/api/site-stats');
    return result;
  }

  Future<Map<String, dynamic>> deleteSite(int siteId) async {
    final result = await _api.post('/api/sites-list.php', {
      'action': 'delete',
      'site_id': siteId,
    });
    _api.invalidateCache('/api/sites-list');
    return result;
  }

  Future<Map<String, dynamic>> syncSales(int siteId) async {
    return await _api
        .post('/api/sync-sales.php', {'site_id': siteId});
  }

  Future<Map<String, dynamic>> deploy(int siteId) async {
    return await _api.post('/api/deploy.php', {'site_id': siteId});
  }
}
