class Sale {
  final int id;
  final int siteId;
  final String? username;
  final num price;
  final String? profileName;
  final String? saleDate;
  final String? saleTime;
  final String? source;
  final int? pointId;
  final num discount;
  final bool void_;
  final String? siteName;
  final String? pointName;

  Sale({
    required this.id,
    required this.siteId,
    this.username,
    required this.price,
    this.profileName,
    this.saleDate,
    this.saleTime,
    this.source,
    this.pointId,
    this.discount = 0,
    this.void_ = false,
    this.siteName,
    this.pointName,
  });

  num get netAmount => price - discount;

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: _toInt(json['id']),
        siteId: _toInt(json['site_id']),
        username: json['username'],
        price: json['price'] ?? 0,
        profileName: json['profile_name'],
        saleDate: json['sale_date'],
        saleTime: json['sale_time'],
        source: json['source'],
        pointId: json['point_id'] != null ? _toInt(json['point_id']) : null,
        discount: json['discount'] ?? 0,
        void_: json['void'] == true || json['void'] == 1,
        siteName: json['site_name'],
        pointName: json['point_name'],
      );

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v.toString()) ?? 0;
}
