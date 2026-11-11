import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/user_model.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_card.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_model.dart';
import 'package:travel_trust_network_mobile/features/messages/chat_screen.dart';
import 'package:travel_trust_network_mobile/features/messages/message_bubble.dart';
import 'package:travel_trust_network_mobile/features/messages/message_model.dart';
import 'package:travel_trust_network_mobile/features/messages/message_service.dart';
import 'package:travel_trust_network_mobile/features/messages/inbox_screen.dart';
import 'package:travel_trust_network_mobile/features/messages/unread_message_badge.dart';

class ChatAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: UserModel(
      id: 'me',
      email: 'me@test.invalid',
      fullName: 'Me',
      trustScore: 50,
      verifiedVisitCount: 0,
      trustScoreLogs: [],
    ),
  );
  void expire() => state = const AuthState();
}

class ChatApi extends ApiService {
  ChatApi() {
    accessToken = 'token';
  }
  final sent = <Map<String, dynamic>>[];
  final paths = <String>[];
  final messages = <Map<String, dynamic>>[];
  List<Map<String, dynamic>>? inboxData;
  List<Map<String, dynamic>> friendData = [];
  bool canSend = true;
  Object? sendError, loadError;
  Completer<Map<String, dynamic>>? pendingSend, pendingOpen;
  Completer<void>? pendingRead;
  Object? readError;
  int readCursor = 0;
  final readRequests = <int>[];
  int get unread => messages
      .where((m) => m['senderId'] != 'me' && (m['id'] as int) > readCursor)
      .length;
  Map<String, dynamic> get conversation => {
    'id': 'chat',
    'peerId': 'peer',
    'peerName': 'Hòa',
    'canSend': canSend,
    'unreadCount': unread,
    'lastMessage': messages.isEmpty ? null : messages.last['body'],
  };
  Map<String, dynamic> message(
    int id,
    String body, {
    String sender = 'me',
    String? quote,
  }) => {
    'id': id,
    'conversationId': 'chat',
    'senderId': sender,
    'clientMessageId': 'client-$id',
    'body': body,
    'sentAt': '2026-11-10T12:00:00',
    if (quote != null)
      'quote': {
        'signalId': quote,
        'mediaId': 'image',
        'senderName': 'Hòa',
        'caption': 'Photo',
      },
  };
  @override
  Future<Map<String, dynamic>> get(String path) async {
    paths.add(path);
    if (loadError != null) throw loadError!;
    if (path.endsWith('/unread-count')) return {'count': unread};
    return conversation;
  }

  @override
  Future<void> putVoid(String path, [Map<String, dynamic>? data]) async {
    if (!path.startsWith('/messages/') || !path.endsWith('/read')) return;
    final cursor = data!['lastReadMessageId'] as int;
    readRequests.add(cursor);
    await pendingRead?.future;
    if (readError != null) throw readError!;
    if (cursor > readCursor) readCursor = cursor;
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    paths.add(path);
    if (path.contains('/with/')) {
      if (pendingOpen != null) return pendingOpen!.future;
      if (loadError != null) throw loadError!;
      return conversation;
    }
    sent.add(Map.of(data));
    if (pendingSend != null) return pendingSend!.future;
    if (sendError != null) throw sendError!;
    final result = {
      ...message(
        messages.length + 1,
        data['body'] as String,
        quote: data['quotedSignalId'] as String?,
      ),
      'clientMessageId': data['clientMessageId'],
    };
    messages.add(result);
    return result;
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    paths.add(path);
    if (loadError != null) throw loadError!;
    if (path.startsWith('/friends')) return friendData;
    if (!path.contains('/messages?')) {
      if (inboxData != null) {
        final page = int.parse(Uri.parse(path).queryParameters['page'] ?? '0');
        return inboxData!.skip(page * 30).take(30).toList();
      }
      return messages.isEmpty ? [] : [conversation];
    }
    final query = Uri.parse(path).queryParameters;
    final before = int.tryParse(query['before'] ?? '');
    final after = int.tryParse(query['after'] ?? '');
    final result =
        messages
            .where(
              (m) =>
                  (before == null || (m['id'] as int) < before) &&
                  (after == null || (m['id'] as int) > after),
            )
            .toList()
          ..sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    if (after != null) return result.reversed.take(50).toList();
    return result.take(50).toList();
  }

  @override
  Future<Uint8List> getPrivateImage(String mediaId) async => Uint8List(0);
}

void main() {
  Finder sendButton([String tooltip = 'Gửi tin nhắn']) =>
      find.byWidgetPredicate((w) => w is IconButton && w.tooltip == tooltip);
  late ChatApi api;
  setUp(() => api = ChatApi());
  tearDown(() => api.close());
  Future<ProviderContainer> open(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(ChatAuth.new),
        ],
        child: MaterialApp(home: child),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  testWidgets(
    'reply on a photo opens private chat with a quote and sends it once',
    (tester) async {
      await open(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            child: LocketCard(
              signal: LocketSignal(
                id: 'photo',
                senderId: 'peer',
                senderName: 'Hòa',
                mediaId: 'image',
                imageUrl: '',
                is360Image: false,
              ),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Trả lời'));
      await tester.tap(find.text('Trả lời'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.byType(PhotoQuotePreview), findsOneWidget);
      expect(api.paths, contains('/messages/conversations/with/peer'));
      await tester.enterText(find.byType(TextField), 'Ảnh đẹp quá');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();
      expect(api.sent.single['quotedSignalId'], 'photo');
      expect(api.sent.single['body'], 'Ảnh đẹp quá');
      expect(find.text('Ảnh đẹp quá'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('new messages refresh automatically and old messages paginate', (
    tester,
  ) async {
    for (var id = 1; id <= 51; id++) {
      api.messages.add(api.message(id, 'Message $id', sender: 'peer'));
    }
    await open(tester, const ChatScreen(conversationId: 'chat'));
    expect(find.text('Message 51'), findsOneWidget);
    api.messages.add(api.message(52, 'New reply', sender: 'peer'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('New reply'), findsOneWidget);
    expect(api.paths.any((p) => p.contains('after=51')), isTrue);
    final older = find.text('Tin nhắn cũ hơn');
    await tester.scrollUntilVisible(
      older,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(older);
    await tester.pumpAndSettle();
    expect(api.paths.any((p) => p.contains('before=2')), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'uncertain retry keeps text, quote and request ID; double submit is blocked',
    (tester) async {
      await open(
        tester,
        const ChatScreen(
          peerId: 'peer',
          quote: PhotoQuote(
            signalId: 'photo',
            mediaId: 'image',
            senderName: 'Hòa',
          ),
        ),
      );
      api.pendingSend = Completer();
      await tester.enterText(find.byType(TextField), 'Keep draft');
      await tester.pump();
      final send = tester.widget<IconButton>(sendButton()).onPressed!;
      send();
      send();
      await tester.pump();
      expect(api.sent, hasLength(1));
      api.pendingSend!.completeError(
        const ApiException('Timeout', isUncertain: true),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      api.pendingSend = null;
      await tester.tap(sendButton('Gửi lại tin nhắn'));
      await tester.pumpAndSettle();
      expect(api.sent, hasLength(2));
      expect(api.sent[0], api.sent[1]);
      expect(find.text('Keep draft'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unfriend keeps history visible and disables new messages', (
    tester,
  ) async {
    api.canSend = false;
    api.messages.add(api.message(1, 'Old private message'));
    await open(tester, const ChatScreen(conversationId: 'chat'));
    expect(find.text('Old private message'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.widget<IconButton>(sendButton()).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sending a new message does not skip an unseen incoming reply', (
    tester,
  ) async {
    api.messages.add(api.message(1, 'First message', sender: 'peer'));
    await open(tester, const ChatScreen(conversationId: 'chat'));
    api.messages.add(api.message(2, 'Unseen incoming', sender: 'peer'));
    await tester.enterText(find.byType(TextField), 'Outgoing third');
    await tester.pump();
    await tester.tap(sendButton());
    await tester.pumpAndSettle();
    expect(api.readRequests.every((id) => id <= 1), isTrue);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Unseen incoming'), findsOneWidget);
    expect(find.text('Outgoing third'), findsOneWidget);
    expect(api.paths.any((p) => p.contains('after=1')), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'load errors retry and an expired session hides cached messages',
    (tester) async {
      api.loadError = const ApiException('Load failed');
      final container = await open(tester, const ChatScreen(peerId: 'peer'));
      expect(find.text('Load failed'), findsOneWidget);
      api.loadError = null;
      api.messages.add(api.message(1, 'Secret'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Secret'), findsOneWidget);
      (container.read(authControllerProvider.notifier) as ChatAuth).expire();
      await tester.pumpAndSettle();
      expect(find.text('Secret'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('closing while sending ignores late success or failure', (
    tester,
  ) async {
    await open(tester, const ChatScreen(peerId: 'peer'));
    api.pendingSend = Completer();
    await tester.enterText(find.byType(TextField), 'Pending');
    await tester.pump();
    await tester.tap(sendButton());
    await tester.pump();
    expect(api.sent, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    api.pendingSend!.completeError(const ApiException('Late failure'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inbox opens a saved conversation without creating another one', (
    tester,
  ) async {
    api.messages.add(api.message(1, 'Existing conversation'));
    await open(tester, const InboxScreen());
    await tester.tap(find.text('Hòa'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(api.paths.where((p) => p.contains('/with/')), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('inbox loads conversations beyond the first page', (
    tester,
  ) async {
    api.inboxData = List.generate(
      35,
      (i) => {
        ...api.conversation,
        'id': 'chat-$i',
        'peerName': 'Peer $i',
        'updatedAt': DateTime(
          2026,
          11,
          10,
          12,
        ).subtract(Duration(minutes: i)).toIso8601String(),
      },
    );
    await open(tester, const InboxScreen());
    final more = find.text('Cuộc trò chuyện cũ hơn');
    await tester.scrollUntilVisible(
      more,
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(api.paths.any((p) => p.contains('page=1')), isTrue);
    await tester.scrollUntilVisible(
      find.text('Peer 34'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Peer 34'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'inbox aggregates different senders and reorders when a new message arrives',
    (tester) async {
      api.inboxData = [
        {
          ...api.conversation,
          'id': 'one',
          'peerName': 'Nam',
          'lastMessage': 'Tin từ Nam',
          'updatedAt': '2026-11-10T10:00:00',
        },
        {
          ...api.conversation,
          'id': 'two',
          'peerName': 'Huyền',
          'lastMessage': 'Tin từ Huyền',
          'updatedAt': '2026-11-10T11:00:00',
        },
      ];
      final container = await open(tester, const InboxScreen());
      expect(find.text('Tin từ Nam'), findsOneWidget);
      expect(find.text('Tin từ Huyền'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Huyền')).dy,
        lessThan(tester.getTopLeft(find.text('Nam')).dy),
      );
      api.inboxData![0] = {
        ...api.inboxData![0],
        'lastMessage': 'Tin mới nhất',
        'updatedAt': '2026-11-10T12:00:00',
      };
      container.invalidate(inboxProvider);
      await tester.pumpAndSettle();
      expect(find.text('Tin mới nhất'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Nam')).dy,
        lessThan(tester.getTopLeft(find.text('Huyền')).dy),
      );
      (container.read(authControllerProvider.notifier) as ChatAuth).expire();
      await tester.pump();
      expect(find.text('Tin mới nhất'), findsNothing);
      expect(find.text('Tin từ Huyền'), findsNothing);
      expect(find.text('Vui lòng đăng nhập lại.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('new chat selects a current friend and opens the correct peer', (
    tester,
  ) async {
    api.friendData = [
      {'id': 'peer', 'fullName': 'Hòa', 'relationship': 'FRIEND'},
    ];
    await open(tester, const InboxScreen());
    await tester.tap(find.byTooltip('Nhắn tin mới'));
    await tester.pumpAndSettle();
    expect(find.text('Nhắn tin với bạn bè'), findsOneWidget);
    await tester.tap(find.text('Hòa'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(
      api.paths.where((p) => p == '/messages/conversations/with/peer'),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'hidden inbox stops polling and refreshes after returning to the tab',
    (tester) async {
      bool active = false;
      late StateSetter change;
      await open(
        tester,
        StatefulBuilder(
          builder: (_, setState) {
            change = setState;
            return InboxScreen(isActive: active);
          },
        ),
      );
      final initial = api.paths
          .where((p) => p.startsWith('/messages/conversations?'))
          .length;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(
        api.paths.where((p) => p.startsWith('/messages/conversations?')).length,
        initial,
      );
      change(() => active = true);
      await tester.pumpAndSettle();
      expect(
        api.paths.where((p) => p.startsWith('/messages/conversations?')).length,
        initial + 1,
      );
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        api.paths.where((p) => p.startsWith('/messages/conversations?')).length,
        initial + 2,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('inbox badges show per-person unread counts and hide zero', (
    tester,
  ) async {
    api.inboxData = [
      {...api.conversation, 'id': 'one', 'peerName': 'Nam', 'unreadCount': 3},
      {...api.conversation, 'id': 'two', 'peerName': 'Huyền', 'unreadCount': 0},
    ];
    await open(tester, const InboxScreen());
    final badge = tester.widget<UnreadMessageBadge>(
      find.byType(UnreadMessageBadge),
    );
    expect(badge.count, 3);
    expect(find.text('3'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Nam')).style?.fontWeight,
      FontWeight.bold,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'navigation badge updates totals, caps 99+, and clears on logout',
    (tester) async {
      api.messages.addAll(
        List.generate(
          102,
          (i) => api.message(i + 1, 'Incoming $i', sender: 'peer'),
        ),
      );
      final container = await open(
        tester,
        const Scaffold(body: MessageNavigationIcon()),
      );
      expect(find.text('99+'), findsOneWidget);
      final materialBadge = tester.widget<Badge>(find.byType(Badge));
      expect(materialBadge.backgroundColor, Colors.red.shade700);
      expect(materialBadge.textColor, Colors.white);
      api.readCursor = 100;
      container.invalidate(unreadMessagesProvider);
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      (container.read(authControllerProvider.notifier) as ChatAuth).expire();
      await tester.pumpAndSettle();
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'read acknowledgement clears counts only after success and retries failure',
    (tester) async {
      api.messages.add(api.message(1, 'Incoming', sender: 'peer'));
      api.readError = const ApiException('Offline');
      final container = await open(
        tester,
        const ChatScreen(conversationId: 'chat'),
      );
      expect(api.readRequests, [1]);
      expect(await container.read(unreadMessagesProvider.future), 1);
      api.readError = null;
      api.pendingRead = Completer<void>();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(api.readRequests, [1, 1]);
      expect(api.unread, 1);
      api.pendingRead!.complete();
      await tester.pumpAndSettle();
      expect(await container.read(unreadMessagesProvider.future), 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('new incoming during a pending read is acknowledged separately', (
    tester,
  ) async {
    api.messages.add(api.message(1, 'First', sender: 'peer'));
    api.pendingRead = Completer<void>();
    await open(tester, const ChatScreen(conversationId: 'chat'));
    expect(api.readRequests, [1]);
    api.messages.add(api.message(2, 'Second', sender: 'peer'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(api.readRequests, [1]);
    api.pendingRead!.complete();
    await tester.pumpAndSettle();
    expect(api.readRequests, [1, 2]);
    expect(api.unread, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background and covered chat do not mark new messages read', (
    tester,
  ) async {
    api.messages.add(api.message(1, 'First', sender: 'peer'));
    await open(tester, const ChatScreen(conversationId: 'chat'));
    expect(api.readRequests, [1]);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    api.messages.add(api.message(2, 'Background', sender: 'peer'));
    await tester.pump(const Duration(seconds: 8));
    expect(api.readRequests, [1]);
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(api.readRequests, [1, 2]);
    final context = tester.element(find.byType(ChatScreen));
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Covered')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    api.messages.add(api.message(3, 'Covered message', sender: 'peer'));
    await tester.pump(const Duration(seconds: 8));
    expect(api.readRequests, [1, 2]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'reading older history keeps arriving messages unread until returning to latest',
    (tester) async {
      api.messages.addAll(
        List.generate(
          35,
          (i) => api.message(i + 1, 'History $i', sender: 'peer'),
        ),
      );
      await open(tester, const ChatScreen(conversationId: 'chat'));
      expect(api.readRequests, [35]);
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(350);
      await tester.pumpAndSettle();
      api.messages.add(api.message(36, 'Newest incoming', sender: 'peer'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(api.readRequests, [35]);
      expect(api.unread, 1);
      list.controller!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(api.readRequests, [35, 36]);
      expect(api.unread, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'open chat keeps receiving and acknowledging messages after access token rotation',
    (tester) async {
      api.messages.add(api.message(1, 'Before refresh', sender: 'peer'));
      await open(tester, const ChatScreen(conversationId: 'chat'));
      api.rotateAccessToken('new-access-token');
      api.messages.add(api.message(2, 'After refresh', sender: 'peer'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('After refresh'), findsOneWidget);
      expect(api.readRequests, contains(2));
      await tester.enterText(find.byType(TextField), 'Reply after refresh');
      await tester.pump();
      await tester.tap(sendButton());
      await tester.pumpAndSettle();
      expect(api.sent.last['body'], 'Reply after refresh');
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('client request IDs are valid distinct UUIDs', () {
    final ids = List.generate(100, (_) => MessageService.newClientId());
    expect(ids.toSet(), hasLength(100));
    for (final id in ids) {
      expect(
        id,
        matches(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      );
    }
  });
}
