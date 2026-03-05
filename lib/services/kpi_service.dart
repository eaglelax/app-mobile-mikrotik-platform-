import '../config/api_config.dart';
import 'api_client.dart';

class KpiService {
  final _api = ApiClient();

  Future<Map<String, dynamic>> fetchRevenue(
      {String period = 'today', List<int>? siteIds}) async {
    final params = <String, String>{'period': period};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    return await _api.get(ApiConfig.kpiRevenue, params);
  }

  Future<Map<String, dynamic>> fetchActivationRate(
      {List<int>? siteIds}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    return await _api.get(ApiConfig.kpiActivation, params);
  }

  Future<Map<String, dynamic>> fetchStockCoverage(
      {List<int>? siteIds}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    return await _api.get(ApiConfig.kpiStockCoverage, params);
  }

  Future<Map<String, dynamic>> fetchStockouts({List<int>? siteIds}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    return await _api.get(ApiConfig.kpiStockouts, params);
  }

  Future<Map<String, dynamic>> fetchSalesMix({List<int>? siteIds}) async {
    final params = <String, String>{};
    if (siteIds != null) params['site_ids'] = siteIds.join(',');
    return await _api.get(ApiConfig.kpiSalesMix, params);
  }

  Future<Map<String, dynamic>> fetchTopSites() async {
    return await _api.get(ApiConfig.kpiTopSites);
  }

  Future<Map<String, dynamic>> fetchTopVendors() async {
    return await _api.get(ApiConfig.kpiTopVendors);
  }

  Future<Map<String, dynamic>> fetchRouterHealth() async {
    return await _api.get(ApiConfig.healthRouters);
  }

  Future<Map<String, dynamic>> fetchVpnHealth() async {
    return await _api.get(ApiConfig.healthVpn);
  }
}
