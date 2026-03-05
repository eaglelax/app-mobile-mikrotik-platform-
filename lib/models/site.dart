class Site {
  final int id;
  final String nom;
  final String? description;
  final String routerIp;
  final int routerPort;
  final String routerUser;
  final String? routerPassword;
  final String status;
  final String? typeActivite;
  final String currency;
  final bool vpnOnly;
  final DateTime? createdAt;
  final DateTime? configuredAt;

  // Stats (from API)
  final int? activeUsers;
  final int? totalVouchers;
  final int? unsoldVouchers;
  final num? todayRevenue;
  final String? routerStatus; // online/offline/degraded

  Site({
    required this.id,
    required this.nom,
    this.description,
    required this.routerIp,
    this.routerPort = 8728,
    this.routerUser = 'admin',
    this.routerPassword,
    this.status = 'nouveau',
    this.typeActivite,
    this.currency = 'XOF',
    this.vpnOnly = false,
    this.createdAt,
    this.configuredAt,
    this.activeUsers,
    this.totalVouchers,
    this.unsoldVouchers,
    this.todayRevenue,
    this.routerStatus,
  });

  bool get isConfigured => status == 'configure';
  bool get isOnline => routerStatus == 'online';

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        id: _toInt(json['id']),
        nom: json['nom'] ?? json['name'] ?? '',
        description: json['description'],
        routerIp: json['router_ip'] ?? '',
        routerPort: _toInt(json['router_port'] ?? 8728),
        routerUser: json['router_user'] ?? 'admin',
        routerPassword: json['router_password'],
        status: json['status'] ?? 'nouveau',
        typeActivite: json['type_activite'],
        currency: json['currency'] ?? 'XOF',
        vpnOnly: json['vpn_only'] == true || json['vpn_only'] == 1,
        createdAt: _tryDate(json['created_at']),
        configuredAt: _tryDate(json['configured_at']),
        activeUsers: json['active_users'] != null
            ? _toInt(json['active_users'])
            : null,
        totalVouchers: json['total_vouchers'] != null
            ? _toInt(json['total_vouchers'])
            : null,
        unsoldVouchers: json['unsold_vouchers'] != null
            ? _toInt(json['unsold_vouchers'])
            : null,
        todayRevenue: json['today_revenue'],
        routerStatus: json['router_status'],
      );

  Map<String, dynamic> toJson() => {
        'nom': nom,
        'description': description,
        'router_ip': routerIp,
        'router_port': routerPort,
        'router_user': routerUser,
        'router_password': routerPassword,
        'type_activite': typeActivite,
        'currency': currency,
        'vpn_only': vpnOnly,
      };

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v.toString()) ?? 0;
  static DateTime? _tryDate(dynamic v) =>
      v != null ? DateTime.tryParse(v.toString()) : null;
}
