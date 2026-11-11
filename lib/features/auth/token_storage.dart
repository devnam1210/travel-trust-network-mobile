import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';

import '../../core/session_tokens.dart';

abstract interface class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

extension SessionPersistence on TokenStorage {
  Future<SessionTokens?> readTokens() async {
    final stored = await read();
    if (stored == null || stored.trim().isEmpty) return null;
    // Existing installations keep their access token until the next explicit login.
    if (!stored.trimLeft().startsWith('{')) {
      return SessionTokens(accessToken: stored);
    }
    return SessionTokens.fromJson(jsonDecode(stored) as Map<String, dynamic>);
  }

  // One encrypted value prevents mismatched access/refresh pairs after an interrupted write.
  Future<void> writeTokens(SessionTokens tokens) =>
      write(jsonEncode(tokens.toJson()));
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
