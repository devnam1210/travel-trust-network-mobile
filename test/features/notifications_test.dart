import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/user_model.dart';
import 'package:travel_trust_network_mobile/features/friends/friends_screen.dart';
import 'package:travel_trust_network_mobile/features/messages/chat_screen.dart';
import 'package:travel_trust_network_mobile/features/messages/unread_message_badge.dart';
import 'package:travel_trust_network_mobile/features/notifications/notification_host.dart';
import 'package:travel_trust_network_mobile/features/notifications/notification_model.dart';
import 'package:travel_trust_network_mobile/features/notifications/notification_service.dart';
import 'package:travel_trust_network_mobile/features/notifications/notifications_screen.dart';
import 'package:travel_trust_network_mobile/features/notifications/push_gateway.dart';

Map<String, dynamic> eventJson(
  int id, {
  String type = 'FRIEND_REQUEST',
  String recipient = 'me',
}) => {
  'id': id,
  'recipientId': recipient,
  'actorId': 'friend',
  'type': type,
  'title': 'Hầu Văn Hòa',
  'body': 'Có thông báo mới $id',
  'targetId': 'target',
  'createdAt': '2026-11-10T09:30:00Z',
  'readAt': null,
};

class NotificationAuth extends AuthController {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: UserModel.fromJson({
      'id': 'me',
      'email': 'me@test.invalid',
      'fullName': 'Tôi',
      'trustScore': 50,
    }),
  );
  void expire() => state = const AuthState();
}

class NotificationApi extends ApiService {
  final calls = <String>[];
  List<Map<String, dynamic>> items = [eventJson(1)];
  final readIds = <String>[];
  int unreadCount = 1;
  int messageCount = 0;
  String? failure;
  Completer<void>? pendingRegistration;
  final stream = StreamController<Map<String, dynamic>>.broadcast();
  int connections = 0, cancellations = 0;

  @override
  Stream<Map<String, dynamic>> notificationEvents(CancelToken cancel) {
    connections++;
    cancel.whenCancel.then((_) => cancellations++);
    return stream.stream;
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    calls.add(path);
    if (path == '/notifications/unread-count') return {'count': unreadCount};
    if (path == '/messages/conversations/unread-count') {
      return {'count': messageCount};
    }
    if (path.startsWith('/messages/')) {
      return {
        'id': 'target',
        'peerId': 'friend',
        'peerName': 'Bạn',
        'canSend': true,
      };
    }
    return {};
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    calls.add(path);
    if (path.startsWith('/notifications?')) {
      if (failure != null) throw ApiException(failure!);
      return items;
    }
    return [];
  }

  @override
  Future<void> putVoid(String path, [Map<String, dynamic>? data]) async {
    calls.add(path);
    if (path == '/notifications/devices') await pendingRegistration?.future;
    if (path.endsWith('/read')) {
      readIds.add(path.split('/')[2]);
      unreadCount = 0;
    }
  }

  @override
  Future<void> deleteWithBody(String path, Map<String, dynamic> data) async {
    calls.add(path);
  }
}

class TestPush extends PushGateway {
  final messages = StreamController<AppNotification>.broadcast();
  final taps = StreamController<AppNotification>.broadcast();
  final tokens = StreamController<String>.broadcast();
  int deleted = 0;
  bool available = true;
  AppNotification? initialMessage;
  @override
  Future<bool> initialize() async => available;
  @override
  Future<String?> token() async => 'deviceInstallation12';
  @override
  Future<void> deleteToken() async {
    deleted++;
  }

  @override
  Stream<String> get tokenChanges => tokens.stream;
  @override
  Stream<AppNotification> get foreground => messages.stream;
  @override
  Stream<AppNotification> get opened => taps.stream;
  @override
  Future<AppNotification?> initial() async => initialMessage;
  Future<void> dispose() async {
    await messages.close();
    await taps.close();
    await tokens.close();
  }
}

Future<ProviderContainer> mountHost(
  WidgetTester tester,
  NotificationApi api,
  TestPush push,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(api),
        authControllerProvider.overrideWith(NotificationAuth.new),
        pushGatewayProvider.overrideWithValue(push),
      ],
      child: MaterialApp(
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appMessengerKey,
        builder: (_, child) => NotificationHost(child: child!),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Trang chính'),
            actions: const [NotificationsButton()],
          ),
          body: const Column(
            children: [Text('Nội dung'), MessageNavigationIcon()],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(NotificationHost)),
  );
}

class NotificationAdapter implements HttpClientAdapter {
  int status = 200;
  Completer<void>? pendingResponse;
  Completer<void>? started;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (started?.isCompleted == false) started!.complete();
    await pendingResponse?.future;
    if (options.path.endsWith('/stream') && status == 200) {
      return ResponseBody(
        Stream.value(
          Uint8List.fromList(
            utf8.encode(
              'event:ready\ndata:{}\n\nevent:notification\ndata:${jsonEncode(eventJson(2))}\n\n',
            ),
          ),
        ),
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    }
    final data = options.path.contains('unread-count')
        ? {'count': 2}
        : options.path == '/notifications?size=30'
        ? [eventJson(1)]
        : null;
    return ResponseBody.fromString(
      jsonEncode({
        'success': status == 200,
        'data': data,
        'message': 'Expired',
      }),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets(
    'message badge refreshes from realtime events and foreground fallback, clears on logout',
    (tester) async {
      final api = NotificationApi()..accessToken = 'jwt';
      final push = TestPush()..available = false;
      final container = await mountHost(tester, api, push);
      Badge badge() => tester.widget<Badge>(
        find.descendant(
          of: find.byType(MessageNavigationIcon),
          matching: find.byType(Badge),
        ),
      );
      expect(badge().isLabelVisible, isFalse);
      api.messageCount = 1;
      api.stream.add(eventJson(21, type: 'MESSAGE'));
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isTrue);
      expect(
        find.descendant(
          of: find.byType(MessageNavigationIcon),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      api.rotateAccessToken('rotated-jwt');
      api.messageCount = 3;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(MessageNavigationIcon),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final before = api.calls
          .where((p) => p == '/messages/conversations/unread-count')
          .length;
      await tester.pump(const Duration(seconds: 10));
      expect(
        api.calls
            .where((p) => p == '/messages/conversations/unread-count')
            .length,
        before,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      api.messageCount = 2;
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(MessageNavigationIcon),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      (container.read(authControllerProvider.notifier) as NotificationAuth)
          .expire();
      await tester.pumpAndSettle();
      expect(badge().isLabelVisible, isFalse);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await api.stream.close();
      await push.dispose();
      api.close();
    },
  );

  test(
    'SSE decoder joins split UTF-8 and data lines, ignores heartbeats',
    () async {
      final bytes = utf8.encode(
        ':keepalive\r\nevent:ready\r\ndata:{}\r\n\r\nevent:heartbeat\ndata:{}\n\nevent:notification\ndata:{"type":"MESSAGE",\ndata:"title":"Hòa"}\n\n',
      );
      final decoded = await decodeNotificationEvents(
        Stream.fromIterable(bytes.map((b) => [b])),
      ).toList();
      expect(decoded, [
        {'type': 'READY'},
        {'type': 'MESSAGE', 'title': 'Hòa'},
      ]);
    },
  );

  test('notification APIs authenticate SSE, paging, mark read, device registration and removal', () async {
    final adapter = NotificationAdapter();
    final api = ApiService(dio: Dio()..httpClientAdapter = adapter)
      ..accessToken = 'jwt';
    final service = NotificationService(api);
    expect((await service.history()).single.id, '1');
    expect(await service.unread(), 2);
    await service.read('1');
    await service.register('fid');
    await service.unregister('fid');
    final events = await service.events(CancelToken()).toList();
    expect(events.last['id'], 2);
    expect(
      adapter.requests.every((r) => r.headers['Authorization'] == 'Bearer jwt'),
      isTrue,
    );
    expect(adapter.requests[2].method, 'PUT');
    expect(adapter.requests[4].method, 'DELETE');
    expect(adapter.requests[4].data, {'token': 'fid'});
    api.close();
  });

  test(
    'late unauthorized notification request cannot expire a new token',
    () async {
      final adapter = NotificationAdapter()..status = 401;
      final api = ApiService(dio: Dio()..httpClientAdapter = adapter)
        ..accessToken = 'jwt';
      int expired = 0;
      api.onVisitUnauthorized = () async {
        expired++;
      };
      await expectLater(
        NotificationService(api).unread(),
        throwsA(isA<ApiException>()),
      );
      expect(expired, 1);
      expect(api.accessToken, isNull);
      api.accessToken = 'fresh';
      await expectLater(
        api.notificationEvents(CancelToken()).toList(),
        throwsA(isA<ApiException>()),
      );
      expect(expired, 2);
      api.accessToken = 'old';
      adapter.pendingResponse = Completer<void>();
      adapter.started = Completer<void>();
      final pending = NotificationService(api).unread();
      final rejected = expectLater(pending, throwsA(isA<ApiException>()));
      await adapter.started!.future;
      api.accessToken = 'new';
      adapter.pendingResponse!.complete();
      await rejected;
      expect(expired, 2);
      expect(api.accessToken, 'new');
      api.close();
    },
  );

  test('logout waits for in-flight registration and removes device before Firebase revocation', () async {
    final api = NotificationApi()..accessToken = 'jwt';
    final push = TestPush();
    final binding = PushRegistration(NotificationService(api), push);
    api.pendingRegistration = Completer<void>();
    final work = binding.register('deviceInstallation12');
    await Future<void>.delayed(Duration.zero);
    final detached = binding.detach();
    expect(push.deleted, 0);
    api.pendingRegistration!.complete();
    await work;
    await detached;
    expect(api.calls, ['/notifications/devices', '/notifications/devices']);
    expect(push.deleted, 1);
    await push.dispose();
    api.close();
  });

  testWidgets(
    'SSE and FCM duplicate events show once; tap opens incoming requests',
    (tester) async {
      final api = NotificationApi()..accessToken = 'jwt';
      final push = TestPush();
      final container = await mountHost(tester, api, push);
      int received = 0;
      final subscription = container.listen(notificationEventProvider, (
        _,
        next,
      ) {
        if (next != null) received++;
      });
      api.stream.add(eventJson(2));
      await tester.pumpAndSettle();
      expect(find.text('Hầu Văn Hòa\nCó thông báo mới 2'), findsOneWidget);
      push.messages.add(AppNotification.fromJson(eventJson(2)));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(received, 1);
      subscription.close();
      await tester.tap(find.text('Xem'));
      await tester.pumpAndSettle();
      expect(find.byType(FriendsScreen), findsOneWidget);
      expect(
        tester.widget<FriendsScreen>(find.byType(FriendsScreen)).initialKind,
        'incoming',
      );
      expect(api.readIds, ['2']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await api.stream.close();
      await push.dispose();
      api.close();
    },
  );

  testWidgets(
    'background push tap and cold-start message open the correct chat',
    (tester) async {
      final api = NotificationApi()..accessToken = 'jwt';
      final push = TestPush()
        ..initialMessage = AppNotification.fromJson(
          eventJson(3, type: 'MESSAGE'),
        );
      await mountHost(tester, api, push);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).conversationId,
        'target',
      );
      expect(api.readIds, ['3']);
      appNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      push.taps.add(AppNotification.fromJson(eventJson(4, type: 'MESSAGE')));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(api.readIds, ['3', '4']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await api.stream.close();
      await push.dispose();
      api.close();
    },
  );

  testWidgets(
    'background cancels SSE, resume reconnects, logout rejects late and wrong-account events',
    (tester) async {
      final api = NotificationApi()..accessToken = 'jwt';
      final push = TestPush();
      final container = await mountHost(tester, api, push);
      expect(api.connections, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(api.cancellations, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.connections, 2);
      api.stream.add(eventJson(8, recipient: 'other'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      (container.read(authControllerProvider.notifier) as NotificationAuth)
          .expire();
      await tester.pumpAndSettle();
      api.stream.add(eventJson(9));
      push.messages.add(AppNotification.fromJson(eventJson(9)));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await api.stream.close();
      await push.dispose();
      api.close();
    },
  );

  testWidgets(
    'history retains missed events and retries errors without Firebase',
    (tester) async {
      final api = NotificationApi()
        ..accessToken = 'jwt'
        ..failure = 'Mất kết nối';
      final push = TestPush()..available = false;
      await mountHost(tester, api, push);
      await tester.tap(find.byTooltip('Thông báo'));
      await tester.pumpAndSettle();
      expect(find.text('Mất kết nối'), findsOneWidget);
      api.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Có thông báo mới 1'), findsOneWidget);
      api.stream.add(eventJson(2));
      await tester.pumpAndSettle();
      expect(find.textContaining('Có thông báo mới 2'), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await api.stream.close();
      await push.dispose();
      api.close();
    },
  );
}
