import '../config/api_config.dart';
import 'api_client.dart';

class TunnelService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> fetchAll() async {
    return await _api.get(ApiConfig.healthVpn);
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
}
