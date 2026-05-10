import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorage {
  SessionStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const _sessionUserIdKey = 'session_user_id';

  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: _sessionUserIdKey, value: userId);
  }

  Future<String?> readUserId() {
    return _secureStorage.read(key: _sessionUserIdKey);
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _sessionUserIdKey);
  }
}
