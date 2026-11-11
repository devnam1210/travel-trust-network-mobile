import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart' as core;
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart'
    as legacy;
import 'package:travel_trust_network_mobile/features/auth/login_screen.dart';
import 'package:travel_trust_network_mobile/features/auth/token_storage.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_service.dart';
import 'package:travel_trust_network_mobile/features/places/place_service.dart';
import 'package:travel_trust_network_mobile/features/profile/edit_profile_screen.dart';
import 'package:travel_trust_network_mobile/features/profile/profile_service.dart';
import 'package:travel_trust_network_mobile/features/reviews/review_service.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_service.dart';
import 'package:travel_trust_network_mobile/main.dart';
import 'package:travel_trust_network_mobile/features/notifications/push_gateway.dart';
import 'package:travel_trust_network_mobile/features/notifications/notification_model.dart';
import 'package:travel_trust_network_mobile/features/notifications/notification_service.dart';

class NoPush extends PushGateway {
  @override
  Future<bool> initialize() async => false;
  @override
  Future<String?> token() async => null;
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<String> get tokenChanges => const Stream.empty();
  @override
  Stream<AppNotification> get foreground => const Stream.empty();
  @override
  Stream<AppNotification> get opened => const Stream.empty();
  @override
  Future<AppNotification?> initial() async => null;
}

class MemoryTokenStorage implements TokenStorage {
  String? _stored;
  String? get token => _stored?.startsWith('{') == true
      ? (jsonDecode(_stored!) as Map<String, dynamic>)['accessToken'] as String?
      : _stored;
  set token(String? value) => _stored = value;
  int reads = 0;
  int writes = 0;
  int clears = 0;

  @override
  Future<String?> read() async {
    reads++;
    return _stored;
  }

  @override
  Future<void> write(String token) async {
    writes++;
    this.token = token;
  }

  @override
  Future<void> clear() async {
    clears++;
    token = null;
  }
}

// Exercise the real Dio interceptor, ApiService, services and AuthController.
class AuthProfileAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Map<String, dynamic> profile = {
    'id': 'user-1',
    'email': 'test@example.com',
    'fullName': 'Test User',
    'bio': null,
    'avatarUrl': null,
    'trustScore': 7,
    'verifiedVisitCount': 1,
    'trustScoreLogs': [],
  };
  int profileStatus = 200;
  int updateStatus = 200;
  bool protectedUnauthorized = false;
  Completer<void>? pendingUpdate;
  Completer<RequestOptions>? updateStarted;

  ResponseBody reply(Object? data, {int status = 200, String? error}) {
    final body = <String, dynamic>{'success': status == 200, 'data': data};
    if (error != null) body['message'] = error;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final path = options.path;
    if (path.startsWith('/auth/')) {
      return reply({'accessToken': 'fresh-token', 'userProfile': profile});
    }
    if (path == '/users/me/profile' && options.method == 'GET') {
      return reply(
        profile,
        status: profileStatus,
        error: 'Profile unavailable',
      );
    }
    if (path == '/users/me/profile' && options.method == 'PUT') {
      if (updateStarted?.isCompleted == false) updateStarted!.complete(options);
      await pendingUpdate?.future;
      if (updateStatus != 200) {
        return reply(null, status: updateStatus, error: 'Update rejected');
      }
      profile = {...profile, ...options.data as Map<String, dynamic>};
      return reply(profile);
    }
    if (protectedUnauthorized &&
        (path == '/visits/my-history' ||
            path == '/locket/feed' ||
            path == '/notifications/devices')) {
      return reply(null, status: 401, error: 'Expired token');
    }
    return reply([]);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AuthProfileAdapter adapter;
  late ApiService api;
  late MemoryTokenStorage storage;

  setUp(() {
    adapter = AuthProfileAdapter();
    api = ApiService(dio: Dio()..httpClientAdapter = adapter);
    storage = MemoryTokenStorage();
  });
  tearDown(() => api.close());

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        core.apiServiceProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
        pushGatewayProvider.overrideWithValue(NoPush()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<AuthController> startController(ProviderContainer container) async {
    final controller = container.read(authControllerProvider.notifier);
    await controller.restoreSession();
    return controller;
  }

  test('401 during device registration expires the session without waiting on its own request', () async {
    final container = createContainer();
    final controller = await startController(container);
    await controller.login('test@example.com', 'password123');
    adapter.protectedUnauthorized = true;
    await container
        .read(pushRegistrationProvider)
        .register('deviceInstallation12')
        .timeout(const Duration(seconds: 5));
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
    expect(storage.token, isNull);
    expect(api.accessToken, isNull);
  });

  for (final register in [false, true]) {
    test(
      '${register ? 'register' : 'login'} saves session and logout clears shared token',
      () async {
        final container = createContainer();
        final controller = await startController(container);
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.signedOut,
        );
        expect(adapter.requests, isEmpty);
        api.accessToken = 'old-token';
        if (register) {
          await controller.register(
            'test@example.com',
            'Test User',
            'password123',
          );
        } else {
          await controller.login('test@example.com', 'password123');
        }
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, register ? '/auth/register' : '/auth/login');
        expect(request.data, {
          'email': 'test@example.com',
          'password': 'password123',
          if (register) 'fullName': 'Test User',
        });
        expect(request.headers['Authorization'], isNull);
        expect(storage.token, 'fresh-token');
        expect(storage.writes, 1);
        expect(api.accessToken, 'fresh-token');
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.authenticated,
        );
        expect(container.read(authControllerProvider).user!.id, 'user-1');

        await api.get('/users/me/profile');
        expect(
          adapter.requests.last.headers['Authorization'],
          'Bearer fresh-token',
        );
        await controller.logout();
        expect(storage.token, isNull);
        expect(storage.clears, 1);
        expect(api.accessToken, isNull);
        expect(
          container.read(authControllerProvider).status,
          AuthStatus.signedOut,
        );
        await api.getList('/places');
        expect(adapter.requests.last.headers['Authorization'], isNull);
      },
    );
  }

  for (final status in [200, 503, 401, 404]) {
    test(
      'restore session preserves existing behavior for profile HTTP $status',
      () async {
        storage.token = 'saved-token';
        adapter.profileStatus = status;
        final container = createContainer();
        final controller = await startController(container);
        expect(adapter.requests.single.path, '/users/me/profile');
        expect(
          adapter.requests.single.headers['Authorization'],
          'Bearer saved-token',
        );
        expect(storage.reads, 1);
        expect(storage.writes, 0);
        final state = container.read(authControllerProvider);
        if (status == 200) {
          expect(state.status, AuthStatus.authenticated);
          expect(state.user!.fullName, 'Test User');
          expect(api.accessToken, 'saved-token');
          expect(storage.token, 'saved-token');
        } else if (status == 503) {
          expect(state.status, AuthStatus.restoreFailed);
          expect(state.error, 'Profile unavailable');
          expect(storage.token, 'saved-token');
          expect(storage.clears, 0);
          expect(api.accessToken, isNull);
          adapter.profileStatus = 200;
          await controller.restoreSession();
          expect(
            container.read(authControllerProvider).status,
            AuthStatus.authenticated,
          );
          expect(api.accessToken, 'saved-token');
        } else {
          expect(state.status, AuthStatus.signedOut);
          expect(
            state.error,
            'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          );
          expect(storage.token, isNull);
          expect(storage.clears, 1);
          expect(api.accessToken, isNull);
        }
      },
    );
  }

  test(
    'all services share injected API and Locket 401 expires the session once',
    () async {
      storage.token = 'saved-token';
      final container = createContainer();
      await startController(container);
      expect(legacy.apiServiceProvider, same(core.apiServiceProvider));
      expect(container.read(core.apiServiceProvider), same(api));
      expect(container.read(authServiceProvider).api, same(api));
      expect(container.read(profileServiceProvider).api, same(api));
      expect(container.read(placeServiceProvider).api, same(api));
      expect(container.read(visitServiceProvider).api, same(api));
      expect(container.read(reviewServiceProvider).api, same(api));
      expect(container.read(locketServiceProvider).api, same(api));
      expect(api.onVisitUnauthorized, isNotNull);

      final googleSession = await container
          .read(authServiceProvider)
          .loginWithGoogleToken(
            email: 'test@example.com',
            fullName: 'Test User',
            idToken: 'google-id-token',
          );
      expect(googleSession.accessToken, 'fresh-token');
      expect(adapter.requests.last.path, '/auth/google');
      expect(adapter.requests.last.data, {
        'email': 'test@example.com',
        'fullName': 'Test User',
        'idToken': 'google-id-token',
        'avatarUrl': null,
        'fcmToken': null,
      });
      expect(adapter.requests.last.headers['Authorization'], isNull);

      adapter.protectedUnauthorized = true;
      await expectLater(
        api.getList('/locket/feed'),
        throwsA(isA<ApiException>()),
      );
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(api.accessToken, isNull);
      expect(storage.clears, 1);
      await expectLater(
        api.getList('/visits/my-history'),
        throwsA(isA<ApiException>()),
      );
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(api.accessToken, isNull);
      expect(storage.token, isNull);
      expect(storage.clears, 1);
      container.invalidate(authControllerProvider);
      expect(api.onVisitUnauthorized, isNull);
    },
  );

  test('profile refresh and update preserve user state, payload and error behavior', () async {
    storage.token = 'saved-token';
    final container = createContainer();
    final controller = await startController(container);
    adapter.profile = {...adapter.profile, 'trustScore': 12};
    await controller.refreshProfile();
    expect(container.read(authControllerProvider).user!.trustScore, 12);

    adapter.pendingUpdate = Completer<void>();
    adapter.updateStarted = Completer<RequestOptions>();
    final update = controller.updateProfile(
      fullName: 'Updated User',
      bio: 'New bio',
      avatarUrl: null,
    );
    expect(container.read(authControllerProvider).isBusy, isTrue);
    expect(container.read(authControllerProvider).user!.fullName, 'Test User');
    await adapter.updateStarted!.future;
    expect(adapter.requests.last.method, 'PUT');
    expect(adapter.requests.last.path, '/users/me/profile');
    expect(
      adapter.requests.last.headers['Authorization'],
      'Bearer saved-token',
    );
    expect(adapter.requests.last.data, {
      'fullName': 'Updated User',
      'bio': 'New bio',
      'avatarUrl': null,
    });
    adapter.pendingUpdate!.complete();
    await update;
    final user = container.read(authControllerProvider).user!;
    expect(user.fullName, 'Updated User');
    expect(user.bio, 'New bio');
    expect(container.read(authControllerProvider).isBusy, isFalse);

    adapter.updateStatus = 400;
    await expectLater(
      controller.updateProfile(fullName: 'Rejected name'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Update rejected',
        ),
      ),
    );
    expect(container.read(authControllerProvider).user, same(user));
    expect(container.read(authControllerProvider).error, 'Update rejected');
    expect(container.read(authControllerProvider).isBusy, isFalse);
    expect(storage.token, 'saved-token');
  });

  testWidgets(
    'AuthGate rebuilds after login, profile edit and logout closes routes',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            core.apiServiceProvider.overrideWithValue(api),
            tokenStorageProvider.overrideWithValue(storage),
            pushGatewayProvider.overrideWithValue(NoPush()),
          ],
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LoginScreen)),
      );
      final controller = container.read(authControllerProvider.notifier);
      final login = controller.login('test@example.com', 'password123');
      await tester.pumpAndSettle();
      await login;
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉnh sửa thông tin'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '');
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Họ và tên không được để trống.'), findsOneWidget);
      expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);

      await tester.ensureVisible(fields.at(0));
      await tester.enterText(fields.at(0), '  Updated User  ');
      await tester.ensureVisible(fields.at(1));
      await tester.enterText(fields.at(1), '  Updated bio  ');
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Updated User'), findsOneWidget);
      expect(find.text('Updated bio'), findsOneWidget);
      expect(find.text('Cập nhật hồ sơ thành công!'), findsOneWidget);
      expect(
        adapter.requests
            .lastWhere(
              (r) => r.path == '/users/me/profile' && r.method == 'PUT',
            )
            .data,
        {'fullName': 'Updated User', 'bio': 'Updated bio', 'avatarUrl': null},
      );

      await tester.tap(find.byTooltip('Chỉnh sửa hồ sơ'));
      await tester.pumpAndSettle();
      await controller.logout();
      await tester.pumpAndSettle();
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(storage.token, isNull);
      expect(api.accessToken, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
