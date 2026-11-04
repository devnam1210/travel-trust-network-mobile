import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/controllers/auth_controller.dart';
import 'package:travel_trust_network_mobile/models/auth_session.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/auth_service.dart';

import 'support/auth_fakes.dart';

class FakeGoogleAuthService extends AuthService {
  FakeGoogleAuthService({required super.api});
  bool canceled = false;

  @override
  Future<AuthSession?> signInWithGoogle() async {
    if (canceled) return null;
    return loginWithGoogleToken(
      email: 'traveler@gmail.com',
      fullName: 'Người du lịch',
      idToken: 'sdk-id-token',
    );
  }
}

void main() {
  late FakeBackend backend;
  late ApiService api;
  late FakeGoogleAuthService auth;
  late MemoryTokenStorage storage;
  late ProviderContainer container;

  setUp(() {
    backend = FakeBackend();
    api = ApiService(dio: Dio()..httpClientAdapter = backend);
    auth = FakeGoogleAuthService(api: api);
    storage = MemoryTokenStorage();
    container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        authServiceProvider.overrideWithValue(auth),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    api.close();
  });

  Future<AuthController> start() async {
    final controller = container.read(authControllerProvider.notifier);
    await pumpEventQueue();
    return controller;
  }

  test(
    'Google exchange sends correct DTO and persists only backend JWT',
    () async {
      final controller = await start();
      await controller.signInWithGoogle();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(storage.token, 'backend-jwt');
      expect(api.accessToken, 'backend-jwt');
      expect(backend.requests.single.path, '/auth/google');
      expect(
        backend.requests.single.headers.containsKey('Authorization'),
        false,
      );
      expect(backend.requests.single.data, {
        'email': 'traveler@gmail.com',
        'fullName': 'Người du lịch',
        'idToken': 'sdk-id-token',
        'avatarUrl': null,
        'fcmToken': null,
      });
    },
  );

  test(
    'canceling Google leaves login usable without any API request',
    () async {
      final controller = await start();
      auth.canceled = true;
      await controller.signInWithGoogle();
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.signedOut);
      expect(state.isBusy, false);
      expect(state.error, isNull);
      expect(backend.requests, isEmpty);
    },
  );

  test('invalid ID token/backend 401 cannot establish a session', () async {
    final controller = await start();
    backend.respond = (_) => apiResponse(
      null,
      status: 401,
      message: 'Invalid or expired Google ID token.',
    );
    await controller.signInWithGoogle();
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
    expect(storage.token, isNull);
    expect(api.accessToken, isNull);
  });

  test('missing backend Google configuration is explained', () async {
    backend.respond = (_) => apiResponse(
      null,
      status: 401,
      message: 'Google login is not configured.',
    );
    await expectLater(
      auth.loginWithGoogleToken(
        email: 'traveler@gmail.com',
        fullName: 'Traveler',
        idToken: 'sdk-token',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('GOOGLE_CLIENT_ID'),
        ),
      ),
    );
  });

  test('empty ID token is rejected before contacting backend', () async {
    await expectLater(
      auth.loginWithGoogleToken(
        email: 'traveler@gmail.com',
        fullName: 'Traveler',
        idToken: '',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(backend.requests, isEmpty);
  });

  test(
    'backend connection error returns to login and keeps secure storage empty',
    () async {
      final controller = await start();
      backend.respond = (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
      await controller.signInWithGoogle();
      expect(
        container.read(authControllerProvider).error,
        contains('Không thể kết nối'),
      );
      expect(storage.token, isNull);
    },
  );
}
