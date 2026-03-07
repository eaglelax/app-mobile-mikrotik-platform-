class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String status;
  final DateTime? lastLogin;
  final Map<String, dynamic>? features;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.status = 'active',
    this.lastLogin,
    this.features,
  });

  bool get isAdmin => role == 'admin';

  bool hasFeature(String feature) {
    if (isAdmin) return true;
    return features?[feature] == true ||
        features?[feature] == 1 ||
        features?['feature_$feature'] == true ||
        features?['feature_$feature'] == 1;
  }

  int getQuota(String resource) {
    if (isAdmin) return 999;
    return features?[resource] ?? features?['max_$resource'] ?? 0;
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
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'status': status,
        if (lastLogin != null) 'last_login': lastLogin!.toIso8601String(),
        if (features != null) 'features': features,
      };
}
