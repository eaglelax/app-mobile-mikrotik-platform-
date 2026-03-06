import 'package:flutter/material.dart';
import '../models/site.dart';
import '../providers/auth_provider.dart';
import '../services/site_service.dart';

class SiteProvider with ChangeNotifier {
  final _service = SiteService();
  AuthProvider? _auth;

  List<Site> _sites = [];
  Site? _selectedSite;
  bool _isLoading = false;
  String? _error;

  List<Site> get sites => _sites;
  List<Site> get configuredSites =>
      _sites.where((s) => s.status == 'configure').toList();
  Site? get selectedSite => _selectedSite;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateAuth(AuthProvider auth) {
    final wasAuth = _auth?.isAuthenticated ?? false;
    _auth = auth;
    if (auth.isAuthenticated && !wasAuth && _sites.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => fetchSites());
    }
  }

  void selectSite(Site? site) {
    _selectedSite = site;
    notifyListeners();
  }

  Future<void> fetchSites() async {
    if (_auth?.isAuthenticated != true) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sites = await _service.fetchAll();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> testConnection(int siteId) async {
    return await _service.testConnection(siteId);
  }

  Future<void> syncSales(int siteId) async {
    await _service.syncSales(siteId);
  }
}
