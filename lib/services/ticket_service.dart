import 'api_client.dart';

class TicketService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> fetchTickets(int siteId,
      {String? status, int page = 1, int limit = 50}) async {
    final params = <String, String>{
      'site_id': siteId.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;
    return await _api.get('/api/hotspot.php', {
      ...params,
      'action': 'vouchers',
    });
  }

  Future<Map<String, dynamic>> generateBatch(int siteId,
      {required String profile,
      required int quantity,
      int? pointId}) async {
    final result = await _api.post('/api/generate-tickets.php', {
      'site_id': siteId,
      'profile_name': profile,
      'quantity': quantity,
      if (pointId != null) 'point_id': pointId,
    }, const Duration(minutes: 5));
    _api.invalidateCache('/api/ticket-batch');
    _api.invalidateCache('/api/hotspot.php');
    return result;
  }

  Future<Map<String, dynamic>> cancelTicket(int siteId, String ticketId) async {
    final result = await _api.post('/api/hotspot.php', {
      'site_id': siteId,
      'action': 'remove_user',
      'id': ticketId,
    });
    _api.invalidateCache('/api/ticket-batch');
    _api.invalidateCache('/api/hotspot.php');
    return result;
  }

  Future<Map<String, dynamic>> fetchBatches(int siteId) async {
    return await _api.getCached('/api/ticket-batches.php',
        params: {'site_id': siteId.toString()},
        ttl: const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> fetchBatchDetail(int siteId, String batchId) async {
    return await _api.getCached('/api/ticket-batch-detail.php',
        params: {'site_id': siteId.toString(), 'batch_id': batchId},
        ttl: const Duration(seconds: 30));
  }

  Future<Map<String, dynamic>> fetchPointTickets(int siteId, int pointId,
      {int page = 1, int limit = 50}) async {
    return await _api.get('/api/point-tickets.php', {
      'site_id': siteId.toString(),
      'point_id': pointId.toString(),
      'page': page.toString(),
      'limit': limit.toString(),
    });
  }

  Future<Map<String, dynamic>> fetchAutoGenBatches(int siteId) async {
    return await _api.get('/api/auto-generate-batches.php', {
      'site_id': siteId.toString(),
    });
  }
}
