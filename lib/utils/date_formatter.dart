import 'package:intl/intl.dart';

class DateHelper {
  // Global readable date formatter
  static String format(String dateStr, {String pattern = "dd MMM yyyy"}) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat(pattern).format(date);
    } catch (_) {
      return dateStr; // if parsing fails
    }
  }

  // Example: Friday, 14 Nov
  static String formatWithDay(String dateStr) {
    return format(dateStr, pattern: "EEEE, dd MMM");
  }

  // Example: 14/11/2025
  static String formatShort(String dateStr) {
    return format(dateStr, pattern: "dd/MM/yyyy");
  }
}
