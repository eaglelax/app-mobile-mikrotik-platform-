class Tunnel {
  final int id;
  final int? siteId;
  final String tunnelLabel;
  final String? vpnIp;
  final int? forwardedApiPort;
  final int? forwardedWinboxPort;
  final int? forwardedWebPort;
  final String status;
  final String? lastHandshake;
  final String? siteName;

  Tunnel({
    required this.id,
    this.siteId,
    required this.tunnelLabel,
    this.vpnIp,
    this.forwardedApiPort,
    this.forwardedWinboxPort,
    this.forwardedWebPort,
    this.status = 'active',
    this.lastHandshake,
    this.siteName,
  });

  bool get isActive => status == 'active';

  factory Tunnel.fromJson(Map<String, dynamic> json) => Tunnel(
        id: _toInt(json['id']),
        siteId: json['site_id'] != null ? _toInt(json['site_id']) : null,
        tunnelLabel: json['tunnel_label'] ?? json['tunnel_name'] ?? '',
        vpnIp: json['vpn_ip'],
        forwardedApiPort: json['forwarded_api_port'] != null
            ? _toInt(json['forwarded_api_port'])
            : null,
        forwardedWinboxPort: json['forwarded_winbox_port'] != null
            ? _toInt(json['forwarded_winbox_port'])
            : null,
        forwardedWebPort: json['forwarded_web_port'] != null
            ? _toInt(json['forwarded_web_port'])
            : null,
        status: json['status'] ?? 'active',
        lastHandshake: json['last_handshake'],
        siteName: json['site_name'],
      );

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v.toString()) ?? 0;
}
