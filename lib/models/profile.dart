class Profile {
  final int? id;
  final String name;
  final String? nameForUsers;
  final int? siteId;
  final String? rateLimit;
  final int? sharedUsers;
  final int? validityValue;
  final String? validityUnit;
  final String? limitUptime;
  final num? ticketPrice;
  final String currency;
  final String status;

  Profile({
    this.id,
    required this.name,
    this.nameForUsers,
    this.siteId,
    this.rateLimit,
    this.sharedUsers,
    this.validityValue,
    this.validityUnit,
    this.limitUptime,
    this.ticketPrice,
    this.currency = 'XOF',
    this.status = 'active',
  });

  String get displayPrice {
    if (ticketPrice == null || ticketPrice == 0) return 'Non défini';
    return '${ticketPrice!.toInt()} $currency';
  }

  String get displayDuration {
    if (validityValue != null && validityUnit != null) {
      const units = {
        'hours': 'h',
        'days': 'j',
        'weeks': 'sem',
        'months': 'mois',
        'minutes': 'min',
      };
      return '$validityValue${units[validityUnit] ?? validityUnit}';
    }
    if (limitUptime != null && limitUptime!.isNotEmpty) return limitUptime!;
    return 'Illimité';
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] != null ? _toInt(json['id']) : null,
        name: json['name'] ?? '',
        nameForUsers: json['name_for_users'],
        siteId: json['site_id'] != null ? _toInt(json['site_id']) : null,
        rateLimit: json['rate_limit'] ?? json['rate-limit'],
        sharedUsers:
            json['shared_users'] != null ? _toInt(json['shared_users']) : null,
        validityValue: json['validity_value'] != null
            ? _toInt(json['validity_value'])
            : null,
        validityUnit: json['validity_unit'],
        limitUptime: json['limit_uptime'] ?? json['limit-uptime'],
        ticketPrice: json['ticket_price'] ?? json['price'],
        currency: json['currency'] ?? 'XOF',
        status: json['status'] ?? 'active',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'name_for_users': nameForUsers,
        'site_id': siteId,
        'rate_limit': rateLimit,
        'shared_users': sharedUsers,
        'validity_value': validityValue,
        'validity_unit': validityUnit,
        'limit_uptime': limitUptime,
        'ticket_price': ticketPrice,
        'currency': currency,
      };

  static int _toInt(dynamic v) =>
      v is int ? v : int.tryParse(v.toString()) ?? 0;
}
