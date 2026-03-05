class Ticket {
  final int id;
  final int siteId;
  final int? profileId;
  final String code;
  final String? password;
  final String? limitUptime;
  final num? price;
  final String status;
  final String? batchId;
  final int? pointId;
  final DateTime? soldAt;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final String? profileName;
  final String? siteName;

  Ticket({
    required this.id,
    required this.siteId,
    this.profileId,
    required this.code,
    this.password,
    this.limitUptime,
    this.price,
    this.status = 'available',
    this.batchId,
    this.pointId,
    this.soldAt,
    this.activatedAt,
    this.expiresAt,
    this.profileName,
    this.siteName,
  });

  bool get isAvailable => status == 'available';
  bool get isUsed => status == 'used';

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: _toInt(json['id']),
        siteId: _toInt(json['site_id']),
        profileId:
            json['profile_id'] != null ? _toInt(json['profile_id']) : null,
        code: json['code'] ?? '',
        password: json['password'],
        limitUptime: json['limit_uptime'],
        price: json['price'],
        status: json['status'] ?? 'available',
        batchId: json['batch_id'],
        pointId: json['point_id'] != null ? _toInt(json['point_id']) : null,
        soldAt: _tryDate(json['sold_at']),
        activatedAt: _tryDate(json['activated_at']),
        expiresAt: _tryDate(json['expires_at']),
        profileName: json['profile_name'],
        siteName: json['site_name'],
      );

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v.toString()) ?? 0;
  static DateTime? _tryDate(dynamic v) =>
      v != null ? DateTime.tryParse(v.toString()) : null;
}
