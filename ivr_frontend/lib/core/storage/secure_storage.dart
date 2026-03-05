import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'user_role';
  static const _emailKey = 'user_email';
  static const _userIdKey = 'user_id';
  static const _panchayatIdKey = 'panchayat_id';

  // Token
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> deleteToken() => _storage.delete(key: _tokenKey);

  // User info
  static Future<void> saveUserInfo({
    required String role,
    required String email,
    required int userId,
    int? panchayatId,
  }) async {
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _emailKey, value: email);
    await _storage.write(key: _userIdKey, value: userId.toString());
    if (panchayatId != null) {
      await _storage.write(key: _panchayatIdKey, value: panchayatId.toString());
    }
  }

  static Future<String?> getRole() => _storage.read(key: _roleKey);
  static Future<String?> getEmail() => _storage.read(key: _emailKey);

  static Future<int?> getUserId() async {
    final val = await _storage.read(key: _userIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  static Future<int?> getPanchayatId() async {
    final val = await _storage.read(key: _panchayatIdKey);
    return val != null ? int.tryParse(val) : null;
  }

  // Clear all
  static Future<void> clearAll() => _storage.deleteAll();
}
