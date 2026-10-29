import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/auth_service.dart';

import 'support/auth_fakes.dart';

void main() {
  late FakeBackend backend;
  late ApiService api;
  late AuthService auth;

  setUp(() {
    backend = FakeBackend();
    api = ApiService(
      dio: Dio()..httpClientAdapter = backend,
      baseUrl: 'https://backend.example/api/v1/',
    );
    auth = AuthService(api: api);
  });

  tearDown(() => api.close());

  test(
    'login sends email/password DTO and parses the backend envelope',
    () async {
      api.accessToken = 'stale-jwt';
      final session = await auth.login(
        email: 'traveler@gmail.com',
        password: 'my-app-password',
      );

      final request = backend.requests.single;
      expect(request.method, 'POST');
      expect(
        request.uri.toString(),
        'https://backend.example/api/v1/auth/login',
      );
      expect(request.data, {
        'email': 'traveler@gmail.com',
        'password': 'my-app-password',
      });
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(session.accessToken, 'backend-jwt');
      expect(session.user.trustScore, 50);
      expect(session.user.trustScoreLogs.single.delta, 50);
    },
  );

  test(
    'register sends full name and password to the matching endpoint',
    () async {
      final session = await auth.register(
        email: 'traveler@gmail.com',
        fullName: 'Người du lịch',
        password: 'my-app-password',
      );

      expect(backend.requests.single.uri.path, '/api/v1/auth/register');
      expect(backend.requests.single.data, {
        'email': 'traveler@gmail.com',
        'fullName': 'Người du lịch',
        'password': 'my-app-password',
      });
      expect(session.user.email, 'traveler@gmail.com');
    },
  );

  test('profile request sends the backend JWT', () async {
    api.accessToken = 'backend-jwt';
    final user = await auth.getProfile();
    expect(
      backend.requests.single.headers['Authorization'],
      'Bearer backend-jwt',
    );
    expect(user.verifiedVisitCount, 2);
  });

  test('backend credentials error reaches the app', () async {
    backend.respond = (_) => apiResponse(
      null,
      status: 401,
      message: 'Email hoặc mật khẩu không đúng.',
    );
    await expectLater(
      auth.login(email: 'traveler@gmail.com', password: 'wrong-password'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isUnauthorized, 'isUnauthorized', true)
            .having(
              (e) => e.message,
              'message',
              'Email hoặc mật khẩu không đúng.',
            ),
      ),
    );
  });

  test('duplicate registration returns a usable error', () async {
    backend.respond = (_) =>
        apiResponse(null, status: 409, message: 'Email đã được đăng ký.');
    await expectLater(
      auth.register(
        email: 'traveler@gmail.com',
        fullName: 'Traveler',
        password: 'my-app-password',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Email đã được đăng ký.',
        ),
      ),
    );
  });

  test('network failures provide a usable error', () async {
    backend.respond = (options) => throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
    await expectLater(
      auth.getProfile(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Không thể kết nối máy chủ'),
        ),
      ),
    );
  });

  test('an empty access token cannot create a session', () async {
    backend.respond = (_) =>
        apiResponse({'accessToken': '', 'userProfile': profileJson()});
    await expectLater(
      auth.login(email: 'traveler@gmail.com', password: 'my-app-password'),
      throwsA(isA<FormatException>()),
    );
  });
}
