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
    return await _api.post('/api/generate-tickets.php', {
      'site_id': siteId,
      'profile_name': profile,
      'quantity': quantity,
      if (pointId != null) 'point_id': pointId,
    });
  }

  Future<Map<String, dynamic>> cancelTicket(int ticketId) async {
    return await _api.post('/api/hotspot.php', {
      'action': 'cancel_voucher',
      'ticket_id': ticketId,
    });
  }

  Future<Map<String, dynamic>> fetchBatches(int siteId) async {
    return await _api.get('/api/auto-generate-batches.php', {
      'site_id': siteId.toString(),
    });
  }
}
