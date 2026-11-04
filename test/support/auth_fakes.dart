import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:travel_trust_network_mobile/services/token_storage.dart';

Map<String, dynamic> profileJson() => {
  'id': 'ca520c3d-180f-4bdd-a7ca-7184dcf9b80d',
  'email': 'traveler@gmail.com',
  'fullName': 'Người du lịch',
  'avatarUrl': null,
  'bio': 'Khám phá Việt Nam',
  'trustScore': 50,
  'verifiedVisitCount': 2,
  'trustScoreLogs': [
    {
      'id': 'log-1',
      'previousScore': 0,
      'delta': 50,
      'newScore': 50,
      'reason': 'Khởi tạo điểm uy tín khi đăng ký tài khoản',
      'policyVersion': 'v1',
      'createdAt': '2026-10-29T10:00:00',
    },
  ],
  'createdAt': '2026-10-29T10:00:00',
};

ResponseBody apiResponse(
  Object? data, {
  int status = 200,
  String message = 'Thành công',
  String? code,
}) => ResponseBody.fromString(
  jsonEncode({
    'success': status < 400,
    'code': code ?? (status < 400 ? 'SUCCESS' : 'UNAUTHORIZED'),
    'message': message,
    'data': data,
    'timestamp': '2026-10-29T10:00:00',
  }),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class FakeBackend implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  FutureOr<ResponseBody> Function(RequestOptions)? respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (respond != null) return respond!(options);
    return apiResponse(
      options.path == '/auth/login' ||
              options.path == '/auth/register' ||
              options.path == '/auth/google'
          ? {'accessToken': 'backend-jwt', 'userProfile': profileJson()}
          : profileJson(),
    );
  }

  @override
  void close({bool force = false}) {}
}

class MemoryTokenStorage implements TokenStorage {
  String? token;
  bool failWrite = false;
  bool failClear = false;
  int clearCount = 0;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async {
    if (failWrite) throw StateError('Storage unavailable');
    this.token = token;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    if (failClear) throw StateError('Storage unavailable');
    token = null;
  }
}
