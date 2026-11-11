import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/core/session_tokens.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/token_storage.dart';
import 'package:travel_trust_network_mobile/features/notifications/push_gateway.dart';

import 'auth_profile_test.dart' show MemoryTokenStorage, NoPush;

class RefreshAdapter implements HttpClientAdapter {
  final calls = <RequestOptions>[];
  final payloads = <int>[];
  final revoked = <String>[];
  final profile = <String, dynamic>{
    'id': 'me',
    'email': 'me@test.invalid',
    'fullName': 'Me',
    'trustScore': 50,
  };
  final rejected = <String>{};
  int refreshes = 0, refreshStatus = 200, logoutStatus = 200;
  Completer<void>? pendingRefresh;
  Completer<void>? refreshStarted;

  ResponseBody json(Object? data, {int status = 200}) =>
      ResponseBody.fromString(
        jsonEncode({
          'success': status == 200,
          'data': data,
          'message': 'Rejected',
        }),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    if (requestStream != null) {
      var bytes = 0;
      await for (final chunk in requestStream) {
        bytes += chunk.length;
      }
      if (options.data is FormData) payloads.add(bytes);
    }
    if (options.path == '/auth/login' || options.path == '/auth/register') {
      return json({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'userProfile': profile,
      });
    }
    if (options.path == '/auth/refresh') {
      refreshes++;
      if (refreshStarted?.isCompleted == false) refreshStarted!.complete();
      await pendingRefresh?.future;
      return json({
        'accessToken': 'access-2',
        'refreshToken': 'refresh-2',
      }, status: refreshStatus);
    }
    if (options.path == '/auth/logout') {
      revoked.add(
        (options.data as Map<String, dynamic>)['refreshToken'] as String,
      );
      return json(null, status: logoutStatus);
    }
    if (rejected.contains(options.headers['Authorization'])) {
      return json(null, status: 401);
    }
    if (options.path == '/notifications/stream') {
      return ResponseBody(
        Stream.value(
          Uint8List.fromList(utf8.encode('event:ready\ndata:{}\n\n')),
        ),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    }
    if (options.path.startsWith('/media/private/') && options.method == 'GET') {
      return ResponseBody.fromBytes(
        [1, 2, 3],
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
        },
      );
    }
    return json(profile);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late RefreshAdapter adapter;
  late ApiService api;
  late MemoryTokenStorage storage;
  late ProviderContainer container;
  late AuthController auth;

  setUp(() async {
    adapter = RefreshAdapter();
    api = ApiService(dio: Dio()..httpClientAdapter = adapter);
    storage = MemoryTokenStorage();
    container = ProviderContainer(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
        pushGatewayProvider.overrideWithValue(NoPush()),
      ],
    );
    auth = container.read(authControllerProvider.notifier);
    await auth.restoreSession();
  });
  tearDown(() {
    container.dispose();
    api.close();
  });

  Future<void> login() => auth.login('me@test.invalid', 'password123');

  test(
    'credentials use one stored value and legacy access tokens still load',
    () async {
      storage.token = 'legacy-access';
      expect((await storage.readTokens())?.accessToken, 'legacy-access');
      expect((await storage.readTokens())?.refreshToken, isNull);
      await login();
      final data = jsonDecode((await storage.read())!) as Map<String, dynamic>;
      expect(data, {'accessToken': 'access-1', 'refreshToken': 'refresh-1'});
      expect(adapter.calls.first.headers['Authorization'], isNull);
    },
  );

  test(
    'reopening app restores an expired access token through refresh',
    () async {
      await storage.writeTokens(
        const SessionTokens(accessToken: 'access-1', refreshToken: 'refresh-1'),
      );
      adapter.rejected.add('Bearer access-1');
      await auth.restoreSession();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(api.accessToken, 'access-2');
      expect((await storage.readTokens())?.refreshToken, 'refresh-2');
      expect(adapter.refreshes, 1);
      expect(
        adapter.calls
            .where((r) => r.path == '/auth/refresh')
            .single
            .headers['Authorization'],
        isNull,
      );
    },
  );

  test(
    'parallel 401 responses share one rotation and replay the same JSON body',
    () async {
      await login();
      final version = api.sessionVersion;
      adapter.rejected.add('Bearer access-1');
      adapter.pendingRefresh = Completer();
      adapter.refreshStarted = Completer();
      final work = Future.wait(
        List.generate(
          5,
          (i) => api.post('/messages/conversations/chat/messages', {
            'clientMessageId': 'id-$i',
            'body': 'message-$i',
          }),
        ),
      );
      await adapter.refreshStarted!.future;
      await Future<void>.delayed(Duration.zero);
      expect(adapter.refreshes, 1);
      adapter.pendingRefresh!.complete();
      expect(await work, hasLength(5));
      expect(adapter.refreshes, 1);
      expect(api.sessionVersion, version);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      for (var i = 0; i < 5; i++) {
        final calls = adapter.calls.where(
          (r) =>
              r.path.contains('/messages/') &&
              (r.data as Map)['clientMessageId'] == 'id-$i',
        );
        expect(calls, hasLength(2));
        expect(calls.last.data, calls.first.data);
        expect(calls.last.headers['Authorization'], 'Bearer access-2');
      }
    },
  );

  test(
    'private bytes and multipart uploads replay with new credentials',
    () async {
      await login();
      adapter.rejected.add('Bearer access-1');
      expect(await api.getPrivateImage('image'), [1, 2, 3]);
      adapter.rejected.add('Bearer access-2');
      // A new session permits a second independent refresh test on a finalized upload stream.
      api.accessToken = 'access-1';
      adapter.rejected.remove('Bearer access-2');
      await api.upload('/media/private', 'assets/images/fpt_hoa_lac.jpg');
      expect(adapter.payloads, hasLength(2));
      expect(adapter.payloads.every((size) => size > 0), isTrue);
      expect(adapter.payloads.first, adapter.payloads.last);
      expect(adapter.calls.every((r) => r.followRedirects == false), isTrue);
    },
  );

  test('SSE reconnects after refresh without expiring the session', () async {
    await login();
    adapter.rejected.add('Bearer access-1');
    final events = await api.notificationEvents(CancelToken()).toList();
    expect(events, [
      {'type': 'READY'},
    ]);
    expect(adapter.refreshes, 1);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });

  test('refresh rejection clears credentials once and does not loop', () async {
    await login();
    adapter.rejected.add('Bearer access-1');
    adapter.refreshStatus = 401;
    await expectLater(
      api.get('/friends'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(adapter.refreshes, 1);
    expect(storage.clears, 1);
    expect(await storage.read(), isNull);
    expect(api.accessToken, isNull);
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
  });

  test('refresh server failure preserves credentials and a later request can retry', () async {
    await login();
    adapter.rejected.add('Bearer access-1');
    adapter.refreshStatus = 503;
    await expectLater(
      api.get('/friends'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
    expect((await storage.readTokens())?.refreshToken, 'refresh-1');
    expect(api.accessToken, 'access-1');
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
    adapter.refreshStatus = 200;
    await api.get('/friends');
    expect(adapter.refreshes, 2);
    expect(api.accessToken, 'access-2');
  });

  test(
    '401 after a successful rotation retries only once then signs out',
    () async {
      await login();
      adapter.rejected.addAll(['Bearer access-1', 'Bearer access-2']);
      await expectLater(api.get('/friends'), throwsA(isA<ApiException>()));
      expect(adapter.refreshes, 1);
      expect(adapter.calls.where((r) => r.path == '/friends'), hasLength(2));
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    },
  );

  test('logout waits for refresh, revokes the latest family credential and clears storage', () async {
    await login();
    adapter.rejected.add('Bearer access-1');
    adapter.pendingRefresh = Completer();
    adapter.refreshStarted = Completer();
    final request = api.get('/friends');
    await adapter.refreshStarted!.future;
    final logout = auth.logout();
    expect(adapter.revoked, isEmpty);
    adapter.pendingRefresh!.complete();
    await request;
    await logout;
    expect(adapter.revoked, ['refresh-2']);
    expect(await storage.read(), isNull);
    expect(api.accessToken, isNull);
    expect(container.read(authControllerProvider).status, AuthStatus.signedOut);
  });

  test(
    'failed logout preserves the stored refresh token for revocation retry',
    () async {
      await login();
      adapter.logoutStatus = 503;
      await auth.logout();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect((await storage.readTokens())?.refreshToken, 'refresh-1');
      adapter.logoutStatus = 200;
      await auth.logout();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
    },
  );

  test('late rotation cannot overwrite credentials belonging to a replacement session', () async {
    await login();
    adapter.rejected.add('Bearer access-1');
    adapter.pendingRefresh = Completer();
    adapter.refreshStarted = Completer();
    final request = api.get('/friends');
    final failure = expectLater(request, throwsA(isA<ApiException>()));
    await adapter.refreshStarted!.future;
    await storage.writeTokens(
      const SessionTokens(
        accessToken: 'other-access',
        refreshToken: 'other-refresh',
      ),
    );
    api.accessToken = 'other-access';
    adapter.pendingRefresh!.complete();
    await failure;
    expect(api.accessToken, 'other-access');
    expect((await storage.readTokens())?.refreshToken, 'other-refresh');
    expect(storage.clears, 0);
  });
}
