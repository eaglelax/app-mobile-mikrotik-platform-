class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String status;
  final DateTime? lastLogin;
  final Map<String, dynamic>? features;
  final int? pointId;
  final int? siteId;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'active',
    this.lastLogin,
    this.features,
    this.pointId,
    this.siteId,
  });

  bool get isAdmin => role == 'admin';
  bool get isGerant => role == 'gerant';

  bool hasFeature(String feature) {
    if (isAdmin) return true;
    return features?[feature] == true ||
        features?[feature] == 1 ||
        features?['feature_$feature'] == true ||
        features?['feature_$feature'] == 1;
  }

  int getQuota(String resource) {
    if (isAdmin) return 999;
    // Prefer numeric max_ key over boolean feature flag
    final val = features?['max_$resource'] ?? features?[resource];
    if (val == null) return 0;
    if (val is bool) return val ? 999 : 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
        name: json['name'] ?? '',
        email: json['email'] ?? '',
        role: json['role'] ?? 'user',
        status: json['status'] ?? 'active',
        lastLogin: json['last_login'] != null
            ? DateTime.tryParse(json['last_login'])
            : null,
        features: json['features'],
        pointId: json['point_id'] != null ? (json['point_id'] is int ? json['point_id'] : int.tryParse(json['point_id'].toString())) : null,
        siteId: json['site_id'] != null ? (json['site_id'] is int ? json['site_id'] : int.tryParse(json['site_id'].toString())) : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'status': status,
        if (lastLogin != null) 'last_login': lastLogin!.toIso8601String(),
        if (features != null) 'features': features,
        if (pointId != null) 'point_id': pointId,
        if (siteId != null) 'site_id': siteId,
      };
}
