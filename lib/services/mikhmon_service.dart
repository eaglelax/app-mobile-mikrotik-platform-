import 'api_client.dart';

class MikhmonService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> fetchDashboard(int siteId) async {
    return await _api
        .get('/api/mikhmon-stats.php', {'site_id': siteId.toString()});
  }

  Future<Map<String, dynamic>> fetchHotspotUsers(int siteId) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'users'});
  }

  Future<Map<String, dynamic>> fetchVouchers(int siteId) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'vouchers'});
  }

  Future<Map<String, dynamic>> fetchActiveUsers(int siteId) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'active'});
  }

  Future<Map<String, dynamic>> fetchHosts(int siteId) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'hosts'});
  }

  Future<Map<String, dynamic>> fetchServers(int siteId) async {
    return await _api
        .get('/api/hotspot-servers.php', {'site_id': siteId.toString()});
  }

  Future<Map<String, dynamic>> fetchProfiles(int siteId) async {
    return await _api.getCached('/api/mikhmon-profiles.php',
        params: {'site_id': siteId.toString()},
        ttl: const Duration(seconds: 30),
        timeout: const Duration(seconds: 60));
  }

  Future<Map<String, dynamic>> addHotspotUser(
      int siteId, Map<String, dynamic> userData) async {
    return await _api
        .post('/api/hotspot.php', {'site_id': siteId, 'action': 'add_user', ...userData});
  }

  Future<Map<String, dynamic>> removeHotspotUser(
      int siteId, String userId) async {
    return await _api.post(
        '/api/hotspot.php', {'site_id': siteId, 'action': 'remove_user', 'id': userId});
  }

  Future<Map<String, dynamic>> removeAllUsers(int siteId) async {
    return await _api.post(
        '/api/hotspot.php', {'site_id': siteId, 'action': 'remove_all_users'}, const Duration(minutes: 3));
  }

  Future<Map<String, dynamic>> generateVouchers(
      int siteId, Map<String, dynamic> params) async {
    return await _api.post(
        '/api/generate-tickets.php', {'site_id': siteId, ...params}, const Duration(minutes: 5));
  }

  Future<Map<String, dynamic>> flashSale(
      int siteId, String profile, {int? pointId}) async {
    return await _api.postForm('/mikhmon/flash-sale.php?site_id=$siteId', {
      'profile': profile,
      if (pointId != null) 'point_id': pointId.toString(),
    });
  }

  Future<Map<String, dynamic>> fetchTraffic(int siteId) async {
    return await _api
        .get('/api/traffic.php', {'site_id': siteId.toString()});
  }

  Future<Map<String, dynamic>> rebootRouter(int siteId) async {
    return await _api
        .post('/api/hotspot.php', {'site_id': siteId, 'action': 'reboot'});
  }

  Future<Map<String, dynamic>> shutdownRouter(int siteId) async {
    return await _api
        .post('/api/hotspot.php', {'site_id': siteId, 'action': 'shutdown'});
  }

  Future<Map<String, dynamic>> fetchSchedulers(int siteId) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'scheduler'});
  }

  Future<Map<String, dynamic>> fetchCookies(int siteId) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'cookies'});
  }

  Future<Map<String, dynamic>> removeCookie(int siteId, String cookieId) async {
    return await _api
        .post('/api/hotspot.php', {'site_id': siteId, 'action': 'remove_cookie', 'id': cookieId});
  }

  Future<Map<String, dynamic>> clearMac(int siteId, String username) async {
    return await _api
        .post('/api/hotspot.php', {'site_id': siteId, 'action': 'clear_mac', 'username': username});
  }

  Future<Map<String, dynamic>> fetchIpBindings(int siteId) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'ip_bindings'});
  }

  Future<Map<String, dynamic>> fetchLogs(int siteId, {String topic = 'hotspot'}) async {
    return await _api
        .get('/api/hotspot.php', {'site_id': siteId.toString(), 'action': 'logs', 'topic': topic});
  }

  Future<Map<String, dynamic>> syncTicketsToDb(int siteId) async {
    return await _api.post(
        '/api/hotspot.php', {'site_id': siteId, 'action': 'sync_to_db'}, const Duration(minutes: 3));
  }

  Future<Map<String, dynamic>> deleteDbTickets(int siteId, {int? pointId}) async {
    return await _api.post(
        '/api/hotspot.php', {
      'site_id': siteId,
      'action': 'delete_db_tickets',
      if (pointId != null) 'point_id': pointId,
    }, const Duration(minutes: 3));
  }

}
