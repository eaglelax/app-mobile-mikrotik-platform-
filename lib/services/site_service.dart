import '../models/site.dart';
import 'api_client.dart';

class SiteService {
  final _api = ApiClient();

  Future<List<Site>> fetchAll() async {
    final data = await _api.get('/api/sites-list.php');
    final sites = data['sites'] as List? ?? [];
    return sites.map((s) => Site.fromJson(s)).toList();
  }

  Future<Map<String, dynamic>> fetchStats(int siteId) async {
    return await _api
        .get('/api/site-stats.php', {'site_id': siteId.toString()});
  }

  Future<Map<String, dynamic>> testConnection(int siteId) async {
    return await _api
        .post('/api/router-test.php', {'site_id': siteId});
  }

  Future<Map<String, dynamic>> createSite(Map<String, dynamic> data) async {
    return await _api.post('/api/full-setup.php', data);
  }

  Future<Map<String, dynamic>> syncSales(int siteId) async {
    return await _api
        .post('/api/sync-sales.php', {'site_id': siteId});
  }

  Future<Map<String, dynamic>> deploy(int siteId) async {
    return await _api.post('/api/deploy.php', {'site_id': siteId});
  }
}
