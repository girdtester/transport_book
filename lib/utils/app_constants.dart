import 'package:shared_preferences/shared_preferences.dart';

class AppConstants {
  static const String appName = 'TMS Prime';
  static const String defaultBusinessName = 'TMS Prime';
  static const String defaultPhone = '+91 0000000000';

  /// Get business name from SharedPreferences, fallback to app name
  static Future<String> getBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name') ?? defaultBusinessName;
  }

  /// Get user phone from SharedPreferences, fallback to default
  static Future<String> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone') ?? '';
    if (phone.isEmpty) return defaultPhone;
    // Add +91 prefix if not already present
    if (phone.startsWith('+91')) return phone;
    if (phone.startsWith('91')) return '+$phone';
    return '+91 $phone';
  }
}
