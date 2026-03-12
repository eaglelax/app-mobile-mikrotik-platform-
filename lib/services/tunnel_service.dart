import '../config/api_config.dart';
import 'api_client.dart';

class TunnelService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> fetchAll() async {
    return await _api.post(ApiConfig.createTunnel, {'action': 'status'});
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return await _api.post(ApiConfig.createTunnel, data);
  }

  Future<Map<String, dynamic>> delete(int tunnelId) async {
    return await _api.post(ApiConfig.createTunnel, {
      'action': 'delete',
      'tunnel_id': tunnelId,
    });
  }

  Future<Map<String, dynamic>> getConfig(int tunnelId) async {
    return await _api.get('/tunnels/config.php', {
      'tunnel_id': tunnelId.toString(),
    });
  }

  Future<Map<String, dynamic>> getStatus(int tunnelId) async {
    return await _api.post(ApiConfig.createTunnel, {
      'action': 'status',
      'tunnel_id': tunnelId,
    });
  }

  Future<Map<String, dynamic>> associate(int tunnelId, int siteId) async {
    return await _api.post(ApiConfig.createTunnel, {
      'action': 'associate',
      'tunnel_id': tunnelId,
      'site_id': siteId,
    });
  }

  Future<Map<String, dynamic>> deployToken(int tunnelId, {String type = 'wg-inject', int ttl = 5}) async {
    return await _api.post(ApiConfig.createTunnel, {
      'action': 'deploy-token',
      'tunnel_id': tunnelId,
      'type': type,
      'ttl': ttl,
    });
  }

  Future<Map<String, dynamic>> gatewayAccess(String slug, String action) async {
    return await _api.post(ApiConfig.gatewayProxy, {
      'action': action,
      'slug': slug,
    });
  }
}
