import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage({this.storage = const FlutterSecureStorage()});

  static const _key = 'ttn_access_token';
  final FlutterSecureStorage storage;

  @override
  Future<String?> read() => storage.read(key: _key);

  @override
  Future<void> write(String token) => storage.write(key: _key, value: token);

  @override
  Future<void> clear() => storage.delete(key: _key);
}
