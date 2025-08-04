// lib/wc/Onboard/app_settings.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyAppVersion = 'app_version';
  static const String _keyLastLoginDate = 'last_login_date';
  static const String _keyUserPreferences = 'user_preferences';

  // Check if it's the first app launch
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstLaunch) ?? true;
  }

  // Mark first launch as complete
  static Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstLaunch, false);
    await prefs.setString(_keyLastLoginDate, DateTime.now().toIso8601String());
  }

  // Check if onboarding was completed
  static Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingCompleted) ?? false;
  }

  // Mark onboarding as completed
  static Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingCompleted, true);
    await setFirstLaunchComplete();
  }

  // App version management
  static Future<void> setAppVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppVersion, version);
  }

  static Future<String?> getAppVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAppVersion);
  }

  // Check if app was updated (version changed)
  static Future<bool> wasAppUpdated(String currentVersion) async {
    final storedVersion = await getAppVersion();
    if (storedVersion == null) {
      await setAppVersion(currentVersion);
      return false;
    }

    if (storedVersion != currentVersion) {
      await setAppVersion(currentVersion);
      return true;
    }

    return false;
  }

  // Last login date
  static Future<DateTime?> getLastLoginDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_keyLastLoginDate);
    return dateString != null ? DateTime.parse(dateString) : null;
  }

  static Future<void> updateLastLoginDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastLoginDate, DateTime.now().toIso8601String());
  }

  // User preferences (theme, notifications, etc.)
  static Future<Map<String, dynamic>> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsString = prefs.getString(_keyUserPreferences);
    if (prefsString == null) {
      return _getDefaultPreferences();
    }

    try {
      // You might want to use a JSON library here
      return _getDefaultPreferences(); // Simplified for now
    } catch (e) {
      return _getDefaultPreferences();
    }
  }

  static Future<void> setUserPreferences(Map<String, dynamic> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert to JSON string when implementing
    await prefs.setString(_keyUserPreferences, preferences.toString());
  }

  static Map<String, dynamic> _getDefaultPreferences() {
    return {
      'theme': 'dark',
      'notifications': true,
      'biometric_auth': false,
      'currency': 'USD',
      'language': 'en',
    };
  }

  // Individual preference getters/setters
  static Future<bool> getBiometricAuthEnabled() async {
    final prefs = await getUserPreferences();
    return prefs['biometric_auth'] ?? false;
  }

  static Future<void> setBiometricAuthEnabled(bool enabled) async {
    final prefs = await getUserPreferences();
    prefs['biometric_auth'] = enabled;
    await setUserPreferences(prefs);
  }

  static Future<bool> getNotificationsEnabled() async {
    final prefs = await getUserPreferences();
    return prefs['notifications'] ?? true;
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await getUserPreferences();
    prefs['notifications'] = enabled;
    await setUserPreferences(prefs);
  }

  static Future<String> getTheme() async {
    final prefs = await getUserPreferences();
    return prefs['theme'] ?? 'dark';
  }

  static Future<void> setTheme(String theme) async {
    final prefs = await getUserPreferences();
    prefs['theme'] = theme;
    await setUserPreferences(prefs);
  }

  static Future<String> getCurrency() async {
    final prefs = await getUserPreferences();
    return prefs['currency'] ?? 'USD';
  }

  static Future<void> setCurrency(String currency) async {
    final prefs = await getUserPreferences();
    prefs['currency'] = currency;
    await setUserPreferences(prefs);
  }

  // Reset methods
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOnboardingCompleted);
    await prefs.remove(_keyFirstLaunch);
  }

  static Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> resetUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserPreferences);
  }

  // Debug/Development helpers
  static Future<void> printAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    print('=== App Settings Debug ===');
    for (String key in keys) {
      final value = prefs.get(key);
      print('$key: $value');
    }
    print('========================');
  }

  // Check if user is returning (has used app before)
  static Future<bool> isReturningUser() async {
    final lastLogin = await getLastLoginDate();
    return lastLogin != null;
  }

  // Get days since last login
  static Future<int> getDaysSinceLastLogin() async {
    final lastLogin = await getLastLoginDate();
    if (lastLogin == null) return 0;

    final now = DateTime.now();
    final difference = now.difference(lastLogin);
    return difference.inDays;
  }
}