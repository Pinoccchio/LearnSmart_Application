import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local storage using SharedPreferences
/// Used for persisting user preferences like Remember Me
class LocalStorageService {
  static const String _keyRememberedEmail = 'remembered_email';
  static const String _keyRememberMe = 'remember_me';

  /// Save the user's email for Remember Me functionality
  static Future<void> saveRememberedEmail(String email) async {
    try {
      print('💾 [LOCAL STORAGE] Saving remembered email: $email');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRememberedEmail, email);
      await prefs.setBool(_keyRememberMe, true);
      print('✅ [LOCAL STORAGE] Email saved successfully');
    } catch (e) {
      print('❌ [LOCAL STORAGE] Failed to save email: $e');
      rethrow;
    }
  }

  /// Get the remembered email if Remember Me was enabled
  static Future<String?> getRememberedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool(_keyRememberMe) ?? false;
      print('🔍 [LOCAL STORAGE] Remember me enabled: $rememberMe');

      if (rememberMe) {
        final email = prefs.getString(_keyRememberedEmail);
        print('📧 [LOCAL STORAGE] Retrieved email: $email');
        return email;
      }
      print('⚠️ [LOCAL STORAGE] Remember me not enabled, returning null');
      return null;
    } catch (e) {
      print('❌ [LOCAL STORAGE] Failed to get email: $e');
      return null;
    }
  }

  /// Check if Remember Me is enabled
  static Future<bool> isRememberMeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyRememberMe) ?? false;
      print('🔍 [LOCAL STORAGE] Remember me enabled check: $enabled');
      return enabled;
    } catch (e) {
      print('❌ [LOCAL STORAGE] Failed to check remember me status: $e');
      return false;
    }
  }

  /// Clear remembered email and disable Remember Me
  static Future<void> clearRememberedEmail() async {
    try {
      print('🗑️ [LOCAL STORAGE] Clearing remembered email');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRememberedEmail);
      await prefs.setBool(_keyRememberMe, false);
      print('✅ [LOCAL STORAGE] Email cleared successfully');
    } catch (e) {
      print('❌ [LOCAL STORAGE] Failed to clear email: $e');
      rethrow;
    }
  }

  /// Clear all local storage (useful for sign out)
  static Future<void> clearAll() async {
    try {
      print('🗑️ [LOCAL STORAGE] Clearing all local storage');
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('✅ [LOCAL STORAGE] All storage cleared');
    } catch (e) {
      print('❌ [LOCAL STORAGE] Failed to clear all: $e');
      rethrow;
    }
  }
}
