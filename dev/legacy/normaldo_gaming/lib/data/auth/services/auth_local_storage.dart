import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthLocalStorage {
  Future<String?> fetchToken();
  Future<void> saveToken(String token);
  Future<void> deleteToken();
}

final class AuthLocalStorageImpl implements AuthLocalStorage {
  static const _key = 'ACCESS_TOKEN';

  const AuthLocalStorageImpl(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  @override
  Future<String?> fetchToken() {
    return _secureStorage.read(key: _key);
  }

  @override
  Future<void> saveToken(String token) {
    return _secureStorage.write(key: _key, value: token);
  }

  @override
  Future<void> deleteToken() {
    return _secureStorage.delete(key: _key);
  }
}
