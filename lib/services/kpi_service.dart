import '../config/api_config.dart';
import 'api_client.dart';

class KpiService {
  final _api = ApiClient();

  /// Unwrap: API returns {success, data: {...}} — we return the inner data
  Map<String, dynamic> _unwrap(Map<String, dynamic> response) {
    final d = response['data'];
    if (d is Map<String, dynamic>) return d;
    // If data is a list, wrap it
    if (d is List) return {'items': d};
    return response;
  }

  Future<Map<String, dynamic>> fetchRevenue(
      {String period = 'day',
      String? dateFrom,
      String? dateTo,
      List<int>? siteIds}) async {
    final params = <String, String>{'period': period};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    return _unwrap(await _api.get(ApiConfig.kpiRevenue, params, ApiConfig.longTimeout));
  }

  Future<Map<String, dynamic>> fetchActivationRate(
      {List<int>? siteIds, bool fast = true}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    if (fast) params['fast'] = '1';
    final timeout = fast ? ApiConfig.timeout : ApiConfig.longTimeout;
    return _unwrap(await _api.get(ApiConfig.kpiActivation, params, timeout));
  }

  Future<Map<String, dynamic>> fetchStockCoverage(
      {List<int>? siteIds, bool fast = true}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    if (fast) params['fast'] = '1';
    final timeout = fast ? ApiConfig.timeout : ApiConfig.longTimeout;
    return _unwrap(await _api.get(ApiConfig.kpiStockCoverage, params, timeout));
  }

  Future<Map<String, dynamic>> fetchStockouts(
      {List<int>? siteIds, bool fast = true}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    if (fast) params['fast'] = '1';
    final timeout = fast ? ApiConfig.timeout : ApiConfig.longTimeout;
    return _unwrap(await _api.get(ApiConfig.kpiStockouts, params, timeout));
  }

  Future<Map<String, dynamic>> fetchSalesMix({List<int>? siteIds}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    return _unwrap(await _api.get(ApiConfig.kpiSalesMix, params));
  }

  Future<Map<String, dynamic>> fetchTopSites() async {
    return _unwrap(await _api.get(ApiConfig.kpiTopSites));
  }

  Future<Map<String, dynamic>> fetchTopVendors() async {
    return _unwrap(await _api.get(ApiConfig.kpiTopVendors));
  }

  Future<Map<String, dynamic>> fetchRouterHealth() async {
    return _unwrap(await _api.get(ApiConfig.healthRouters));
  }

  Future<Map<String, dynamic>> fetchVpnHealth() async {
    return _unwrap(await _api.get(ApiConfig.healthVpn));
  }
}
