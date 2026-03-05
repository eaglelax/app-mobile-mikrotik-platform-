import 'package:intl/intl.dart';

class Fmt {
  static final _currencyFmt = NumberFormat('#,###', 'fr_FR');

  static String currency(num amount, [String unit = 'FCFA']) {
    return '${_currencyFmt.format(amount)} $unit';
  }

  static String number(num n) => _currencyFmt.format(n);

  static String percent(num n) => '${n.toStringAsFixed(1)}%';

  static String date(DateTime dt) => DateFormat('dd/MM/yyyy').format(dt);

  static String dateTime(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm').format(dt);

  static String time(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String dateShort(DateTime dt) => DateFormat('dd MMM', 'fr').format(dt);

  static String duration(String? uptime) {
    if (uptime == null || uptime.isEmpty) return 'Illimité';
    return uptime;
  }

  static String bytes(num bytes) {
    if (bytes < 1024) return '${bytes.toInt()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return date(dt);
  }
}
