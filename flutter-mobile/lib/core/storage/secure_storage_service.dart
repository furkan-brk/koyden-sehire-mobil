import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kUserId = 'user_id';
  static const _kUserRole = 'user_role';
  static const _kUserStatus = 'user_status';
  static const _kDisplayName = 'display_name';
  static const _kRememberMe = 'remember_me';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  Future<void> saveToken(String token) =>
      _storage.write(key: _kAccessToken, value: token);

  Future<String?> getToken() => _storage.read(key: _kAccessToken);

  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _kRefreshToken, value: token);

  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);

  Future<void> saveUserInfo({
    required String id,
    required String role,
    required String status,
    String? displayName,
  }) async {
    await Future.wait([
      _storage.write(key: _kUserId, value: id),
      _storage.write(key: _kUserRole, value: role),
      _storage.write(key: _kUserStatus, value: status),
      if (displayName != null)
        _storage.write(key: _kDisplayName, value: displayName),
    ]);
  }

  Future<String?> getUserId() => _storage.read(key: _kUserId);
  Future<String?> getUserRole() => _storage.read(key: _kUserRole);
  Future<String?> getUserStatus() => _storage.read(key: _kUserStatus);
  Future<String?> getDisplayName() => _storage.read(key: _kDisplayName);

  Future<void> saveRememberMe(bool value) =>
      _storage.write(key: _kRememberMe, value: value.toString());

  /// Returns `true` (persist session) by default when the key has never been written.
  Future<bool> getRememberMe() async {
    final v = await _storage.read(key: _kRememberMe);
    return v != 'false';
  }

  Future<void> clearAll() => _storage.deleteAll();
}
