class ApiConfig {
  // Change this to your server URL
  static const String baseUrl = 'https://tikadmin.com';
  // For local development:
  // static const String baseUrl = 'http://192.168.1.100:8888';

  static const Duration timeout = Duration(seconds: 30);

  // API endpoints
  static const String login = '/api/auth/login.php';
  static const String register = '/api/auth/register.php';
  static const String dashboardStats = '/api/dashboard-stats.php';
  static const String sitesList = '/api/sites-list.php';
  static const String analyticsSummary = '/api/analytics-summary.php';
  static const String siteStats = '/api/site-stats.php';
  static const String routerTest = '/api/router-test.php';
  static const String sync = '/api/sync.php';
  static const String syncSales = '/api/sync-sales.php';
  static const String hotspot = '/api/hotspot.php';
  static const String hotspotServers = '/api/hotspot-servers.php';
  static const String profiles = '/api/profiles.php';
  static const String points = '/api/points.php';
  static const String generateTickets = '/api/generate-tickets.php';
  static const String notifications = '/api/notifications.php';
  static const String traffic = '/api/traffic.php';
  static const String mikmonStats = '/api/mikhmon-stats.php';
  static const String mikmonProfiles = '/api/mikhmon-profiles.php';
  static const String deploy = '/api/deploy.php';
  static const String fullSetup = '/api/full-setup.php';
  static const String createTunnel = '/api/create-tunnel.php';
  static const String diagnostic = '/api/diagnostic.php';
  static const String alerts = '/api/alerts.php';
  static const String autoGenConfig = '/api/auto-generate-config.php';
  static const String autoGenBatches = '/api/auto-generate-batches.php';
  static const String autoGenStatus = '/api/auto-generate-status.php';
  static const String usersBulk = '/api/users-bulk.php';

  // KPI endpoints
  static const String kpiRevenue = '/api/kpi/revenue.php';
  static const String kpiActivation = '/api/kpi/activation-rate.php';
  static const String kpiStockCoverage = '/api/kpi/stock-coverage.php';
  static const String kpiStockouts = '/api/kpi/stockouts.php';
  static const String kpiSalesMix = '/api/kpi/sales-mix.php';
  static const String kpiTopSites = '/api/kpi/top-sites.php';
  static const String kpiTopVendors = '/api/kpi/top-vendors.php';

  // Health
  static const String healthRouters = '/api/health/routers.php';
  static const String healthVpn = '/api/health/vpn.php';
}
