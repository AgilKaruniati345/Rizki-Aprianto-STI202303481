import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUsername = 'username';
  static const String _keyPassword = 'user_password'; // Key untuk password

  // Username yang benar (fixed)
  static const String correctUsername = 'kelompokkita123';

  // Password default (bisa diubah user)
  static const String defaultPassword = 'kelompokkita123';

  // Login dengan password dinamis
  Future<bool> login(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();

    // Ambil password yang tersimpan (atau gunakan default jika belum pernah diubah)
    String savedPassword = prefs.getString(_keyPassword) ?? defaultPassword;

    // Cek username dan password
    if (username == correctUsername && password == savedPassword) {
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUsername, username);
      return true;
    }
    return false;
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, false);
    await prefs.remove(_keyUsername);
  }

  // Check login status
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Get username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  // Get current password (untuk display di settings)
  Future<String> getCurrentPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPassword) ?? defaultPassword;
  }

  // Update password (dipanggil dari settings)
  Future<bool> updatePassword(String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyPassword, newPassword);
  }

  // Reset password ke default (opsional - untuk fitur "lupa password")
  Future<bool> resetPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.setString(_keyPassword, defaultPassword);
  }
}
