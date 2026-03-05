class Point {
  final int id;
  final int siteId;
  final int? hotspotServerId;
  final String name;
  final String type;
  final String? description;
  final String? contactName;
  final String? contactPhone;
  final bool isActive;
  final String? serverName;
  final String? siteName;

  Point({
    required this.id,
    required this.siteId,
    this.hotspotServerId,
    required this.name,
    this.type = 'vendeur',
    this.description,
    this.contactName,
    this.contactPhone,
    this.isActive = true,
    this.serverName,
    this.siteName,
  });

  factory Point.fromJson(Map<String, dynamic> json) => Point(
        id: _toInt(json['id']),
        siteId: _toInt(json['site_id']),
        hotspotServerId: json['hotspot_server_id'] != null
            ? _toInt(json['hotspot_server_id'])
            : null,
        name: json['name'] ?? '',
        type: json['type'] ?? 'vendeur',
        description: json['description'],
        contactName: json['contact_name'],
        contactPhone: json['contact_phone'],
        isActive: json['is_active'] != false && json['is_active'] != 0,
        serverName: json['server_name'],
        siteName: json['site_name'],
      );

  Map<String, dynamic> toJson() => {
        'site_id': siteId,
        'hotspot_server_id': hotspotServerId,
        'name': name,
        'type': type,
        'description': description,
        'contact_name': contactName,
        'contact_phone': contactPhone,
        'is_active': isActive,
      };

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v.toString()) ?? 0;
}
