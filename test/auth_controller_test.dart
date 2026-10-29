import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/controllers/auth_controller.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';

import 'support/auth_fakes.dart';

void main() {
  late FakeBackend backend;
  late ApiService api;
  late MemoryTokenStorage storage;
  late ProviderContainer container;
  late AuthController controller;

  setUp(() {
    backend = FakeBackend();
    api = ApiService(dio: Dio()..httpClientAdapter = backend);
    storage = MemoryTokenStorage();
    container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    api.close();
  });

  AuthState state() => container.read(authControllerProvider);

  Future<void> start() async {
    controller = container.read(authControllerProvider.notifier);
    await pumpEventQueue();
  }

  test(
    'no saved token opens the login screen without requesting a profile',
    () async {
      await start();
      expect(state().status, AuthStatus.signedOut);
      expect(backend.requests, isEmpty);
    },
  );

  test(
    'login persists the backend token and logout clears the session',
    () async {
      await start();
      await controller.login('traveler@gmail.com', 'my-app-password');
      expect(state().status, AuthStatus.authenticated);
      expect(state().user?.email, 'traveler@gmail.com');
      expect(storage.token, 'backend-jwt');
      expect(api.accessToken, 'backend-jwt');

      await controller.logout();
      expect(state().status, AuthStatus.signedOut);
      expect(state().user, isNull);
      expect(storage.token, isNull);
      expect(api.accessToken, isNull);
      expect(backend.requests.single.path, '/auth/login');
    },
  );

  test('saved token is validated using the backend profile endpoint', () async {
    storage.token = 'saved-jwt';
    await start();
    expect(state().status, AuthStatus.authenticated);
    expect(
      backend.requests.single.headers['Authorization'],
      'Bearer saved-jwt',
    );
    expect(backend.requests.single.path, '/users/me/profile');
  });

  test('expired token is cleared and login is required again', () async {
    storage.token = 'expired-jwt';
    backend.respond = (_) => apiResponse(null, status: 401);
    await start();
    expect(state().status, AuthStatus.signedOut);
    expect(state().error, contains('hết hạn'));
    expect(storage.token, isNull);
    expect(api.accessToken, isNull);
  });

  test(
    'temporary server failure retains the saved token and supports retry',
    () async {
      storage.token = 'saved-jwt';
      backend.respond = (_) => apiResponse(null, status: 503);
      await start();
      expect(state().status, AuthStatus.restoreFailed);
      expect(storage.token, 'saved-jwt');
      expect(api.accessToken, isNull);

      backend.respond = null;
      await controller.restoreSession();
      expect(state().status, AuthStatus.authenticated);
      expect(api.accessToken, 'saved-jwt');
    },
  );

  test('invalid credentials leave a signed-out state with an error', () async {
    await start();
    backend.respond = (_) =>
        apiResponse(null, status: 401, message: 'Sai mật khẩu');
    await controller.login('traveler@gmail.com', 'wrong-password');
    expect(state().status, AuthStatus.signedOut);
    expect(state().isBusy, false);
    expect(state().error, 'Sai mật khẩu');
    expect(storage.token, isNull);
  });

  test('repeated taps cannot launch concurrent login requests', () async {
    await start();
    final pending = Completer<ResponseBody>();
    backend.respond = (_) => pending.future;
    final first = controller.login('traveler@gmail.com', 'my-app-password');
    await controller.login('traveler@gmail.com', 'my-app-password');
    expect(state().isBusy, true);
    await pumpEventQueue();
    expect(backend.requests, hasLength(1));

    pending.complete(
      apiResponse({'accessToken': 'backend-jwt', 'userProfile': profileJson()}),
    );
    await first;
    expect(backend.requests, hasLength(1));
    expect(state().status, AuthStatus.authenticated);
  });

  test('token storage failure cannot leave the app authenticated', () async {
    await start();
    storage.failWrite = true;
    await controller.login('traveler@gmail.com', 'my-app-password');
    expect(state().status, AuthStatus.signedOut);
    expect(state().error, isNotNull);
    expect(api.accessToken, isNull);
  });

  test(
    'logout reports failure when the persisted token cannot be removed',
    () async {
      storage.token = 'saved-jwt';
      await start();
      storage.failClear = true;
      await controller.logout();
      expect(state().status, AuthStatus.authenticated);
      expect(state().error, contains('đăng xuất lại'));
      expect(storage.token, 'saved-jwt');
    },
  );

  test('logout from restored session clears the saved JWT', () async {
    storage.token = 'saved-jwt';
    await start();
    await controller.logout();
    expect(state().status, AuthStatus.signedOut);
    expect(storage.token, isNull);
  });

  test('unauthorized profile refresh invalidates an active session', () async {
    storage.token = 'saved-jwt';
    await start();
    backend.respond = (_) => apiResponse(null, status: 401);
    await controller.refreshProfile();
    expect(state().status, AuthStatus.signedOut);
    expect(storage.token, isNull);
    expect(api.accessToken, isNull);
  });

  test('registration persists the JWT and exposes the new profile', () async {
    await start();
    await controller.register(
      'traveler@gmail.com',
      'Người du lịch',
      'my-app-password',
    );
    expect(state().status, AuthStatus.authenticated);
    expect(state().user?.fullName, 'Người du lịch');
    expect(backend.requests.single.path, '/auth/register');
    expect(storage.token, 'backend-jwt');
  });
}
