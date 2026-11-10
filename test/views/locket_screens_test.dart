import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/user_model.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_feed_screen.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_service.dart';
import 'package:travel_trust_network_mobile/features/locket/send_locket_screen.dart';
import 'package:travel_trust_network_mobile/features/locket/private_locket_image.dart';
import 'package:travel_trust_network_mobile/features/friends/friend_service.dart';

class LocketScreenApi extends ApiService {
  final uploads = <({String path, String filePath})>[];
  final signals = <({String path, Map<String, dynamic> data})>[];
  final friendRequests = <String>[];
  int feedLoads = 0;
  Object? uploadError;
  Object? signalError;
  Object? feedError;
  Object? friendsError;
  List<Map<String, dynamic>> friends = [
    {
      'id': 'friend-1',
      'fullName': 'Friend One',
      'username': 'friend_one',
      'relationship': 'FRIEND',
    },
    {
      'id': 'friend-2',
      'fullName': 'Friend Two',
      'username': 'friend_two',
      'relationship': 'FRIEND',
    },
  ];
  Completer<Map<String, dynamic>>? pendingUpload;
  Completer<Map<String, dynamic>>? pendingSignal;
  Completer<Map<String, dynamic>>? pendingReaction;
  Completer<List<dynamic>>? pendingFeed;
  List<Map<String, dynamic>>? feedItems;
  final reactionCalls = <String?>[];
  final loadedPaths = <String>[];
  List<Map<String, dynamic>> reactions = [];
  bool privateImage = false;
  int imageLoads = 0;
  Uint8List? imageBytes;

  Map<String, dynamic> get signal => {
    'id': 'signal-1',
    'senderName': 'Test User',
    'imageUrl': '',
    'caption': 'Hello',
    'is360Image': false,
    'mediaId': privateImage ? 'media-1' : null,
    'sentAt': '2026-11-10T10:00:00',
    'reactions': reactions,
  };

  @override
  Future<Map<String, dynamic>> upload(String path, String filePath) async {
    uploads.add((path: path, filePath: filePath));
    if (pendingUpload != null) return pendingUpload!.future;
    if (uploadError != null) throw uploadError!;
    return {'mediaId': 'media-1'};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    if (path.startsWith('/friends/requests/')) {
      friendRequests.add(path.split('/').last);
      return {'sent': true};
    }
    signals.add((path: path, data: Map.of(data)));
    if (pendingSignal != null) return pendingSignal!.future;
    if (signalError != null) throw signalError!;
    return signal;
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    loadedPaths.add(path);
    if (path.startsWith('/friends/search')) {
      return friends
          .map(
            (person) => {
              ...person,
              'relationship': friendRequests.contains(person['id'])
                  ? 'OUTGOING'
                  : 'NONE',
              'relationshipId': friendRequests.contains(person['id'])
                  ? 'request-${person['id']}'
                  : null,
            },
          )
          .toList();
    }
    if (path.startsWith('/friends')) {
      if (friendsError != null) throw friendsError!;
      return friends;
    }
    feedLoads++;
    if (pendingFeed != null) return pendingFeed!.future;
    if (feedError != null) throw feedError!;
    return feedItems ?? (signals.isEmpty ? [] : [signal]);
  }

  @override
  Future<Uint8List> getPrivateImage(String mediaId) async {
    imageLoads++;
    return imageBytes ?? Uint8List(0);
  }

  @override
  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    reactionCalls.add(data?['emoji'] as String?);
    if (pendingReaction != null) return pendingReaction!.future;
    reactions = [
      {'userId': 'user-1', 'userName': 'Me', 'emoji': data!['emoji']},
    ];
    return signal;
  }

  @override
  Future<Map<String, dynamic>> delete(String path) async {
    reactionCalls.add(null);
    reactions = [];
    return signal;
  }
}

class LocketScreenAuth extends AuthController {
  void signOutForTest() => state = const AuthState();
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: UserModel(
      id: 'user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      trustScore: 0,
      verifiedVisitCount: 0,
      trustScoreLogs: [],
    ),
  );
}

void main() {
  const pickerChannel = MethodChannel('plugins.flutter.io/image_picker');
  final imagePath = File('assets/images/fpt_hoa_lac.jpg').absolute.path;
  late LocketScreenApi api;
  bool? navigationResult;

  setUp(() {
    api = LocketScreenApi();
    navigationResult = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, null);
    api.close();
  });

  Finder sendButton() => find.widgetWithText(FilledButton, 'Gửi');

  Future<ProviderContainer> openSend(
    WidgetTester tester, {
    bool withImage = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(LocketScreenAuth.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  navigationResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => SendLocketScreen(
                        placeId: 'place-1',
                        initialFilePath: withImage ? imagePath : null,
                      ),
                    ),
                  );
                },
                child: const Text('Open send'),
              ),
            ),
          ),
        ),
      ),
    );
    // Decode before Image.file is mounted so file I/O runs outside fake async.
    await tester.runAsync(() async {
      await precacheImage(
        FileImage(File(imagePath)),
        tester.element(find.text('Open send')),
      );
    });
    await tester.tap(find.text('Open send'));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SendLocketScreen)),
    );
  }

  Future<void> startSend(WidgetTester tester) async {
    await tester.ensureVisible(sendButton());
    await tester.tap(sendButton());
    await tester.pump();
  }

  testWidgets('camera/gallery preserve picker options, preview and draft', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    Object? pickerError;
    String? pickedPath = imagePath;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (call) async {
          calls.add(call);
          if (pickerError != null) throw pickerError;
          return pickedPath;
        });
    await openSend(tester, withImage: false);
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);
    expect(find.text('Chưa chọn ảnh'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('empty-preview'))),
      tester.getSize(find.byType(AspectRatio)),
    );
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    expect(calls.single.method, 'pickImage');
    expect(calls.single.arguments, containsPair('source', 1));
    expect(calls.single.arguments, containsPair('maxWidth', 1920.0));
    expect(calls.single.arguments, containsPair('imageQuality', 85));
    final preview = tester.widget<Image>(find.byType(Image));
    expect(
      tester.getSize(find.byType(Image)),
      tester.getSize(find.byType(AspectRatio)),
    );
    final resized = preview.image as ResizeImage;
    expect((resized.imageProvider as FileImage).file.path, imagePath);
    expect(resized.width, lessThanOrEqualTo(2048));
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNotNull);

    pickedPath = null;
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(calls.last.arguments, containsPair('source', 0));
    expect(find.byType(Image), findsOneWidget);
    pickerError = PlatformException(code: 'camera_denied');
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được camera/thư viện ảnh.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Draft',
    );
    expect(api.uploads, isEmpty);
  });

  testWidgets('upload failure preserves form and never sends a signal', (
    tester,
  ) async {
    api.uploadError = const ApiException('Upload failed');
    await openSend(tester);
    await tester.enterText(find.byType(TextField), 'Keep this caption');
    await startSend(tester);
    await tester.pumpAndSettle();
    expect(api.uploads.single.path, '/media/private');
    expect(api.uploads.single.filePath, imagePath);
    expect(api.signals, isEmpty);
    expect(find.text('Upload failed'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep this caption',
    );
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNotNull);
    expect(navigationResult, isNull);
  });

  testWidgets('signal failure keeps draft without automatic retry or refresh', (
    tester,
  ) async {
    api.signalError = const ApiException('Signal failed');
    final container = await openSend(tester);
    final subscription = container.listen(locketFeedProvider, (_, _) {});
    addTearDown(subscription.close);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  My caption  ');
    await startSend(tester);
    await tester.pumpAndSettle();
    expect(api.uploads, hasLength(1));
    expect(api.signals.single.path, '/locket/send-signal');
    expect(api.signals.single.data, {
      'mediaId': 'media-1',
      'allFriends': true,
      'recipientIds': [],
      'placeId': 'place-1',
      'caption': 'My caption',
      'is360Image': false,
    });
    expect(api.feedLoads, 1);
    expect(find.text('Signal failed'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '  My caption  ',
    );
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNotNull);
    expect(navigationResult, isNull);
  });

  testWidgets('send success blocks duplicates, refreshes feed and pops true', (
    tester,
  ) async {
    api.pendingUpload = Completer();
    api.pendingSignal = Completer();
    final container = await openSend(tester);
    final subscription = container.listen(locketFeedProvider, (_, _) {});
    addTearDown(subscription.close);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Hello  ');
    await tester.ensureVisible(sendButton());
    final submit = tester.widget<FilledButton>(sendButton()).onPressed!;
    submit();
    submit();
    await tester.pump();
    expect(api.uploads, hasLength(1));
    expect(api.signals, isEmpty);
    expect(find.text('Đang gửi…'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    for (final button in tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    )) {
      expect(button.onPressed, isNull);
    }
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Đang gửi…'))
          .onPressed,
      isNull,
    );
    api.pendingUpload!.complete({'mediaId': 'media-1'});
    await tester.pump();
    expect(api.signals, hasLength(1));
    expect(api.signals.single.data['caption'], 'Hello');
    expect(api.feedLoads, 1);
    api.pendingSignal!.complete(api.signal);
    await tester.pumpAndSettle();
    expect(navigationResult, isTrue);
    expect(find.byType(SendLocketScreen), findsNothing);
    expect(find.text('Đã gửi ảnh lên Locket'), findsOneWidget);
    expect(api.feedLoads, 2);
    expect(
      container.read(locketFeedProvider).requireValue.single.id,
      'signal-1',
    );
  });

  for (final stage in ['upload', 'signal']) {
    for (final fails in [false, true]) {
      testWidgets(
        'closing during $stage safely ignores completion (fails=$fails)',
        (tester) async {
          final pending = Completer<Map<String, dynamic>>();
          if (stage == 'upload') {
            api.pendingUpload = pending;
          } else {
            api.pendingSignal = pending;
          }
          await openSend(tester);
          await startSend(tester);
          expect(api.uploads, hasLength(1));
          expect(api.signals, hasLength(stage == 'signal' ? 1 : 0));
          await tester.pageBack();
          await tester.pumpAndSettle();
          if (fails) {
            pending.completeError(const ApiException('Late error'));
          } else {
            pending.complete(
              stage == 'upload' ? {'mediaId': 'media-1'} : api.signal,
            );
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Open send'), findsOneWidget);
          expect(find.text('Late error'), findsNothing);
          expect(find.text('Đã gửi ảnh lên Locket'), findsNothing);
          expect(api.signals, hasLength(stage == 'signal' ? 1 : 0));
          expect(navigationResult, isNull);
        },
      );
    }
  }

  testWidgets('closing while picker is open ignores the selected file', (
    tester,
  ) async {
    final picked = Completer<String?>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pickerChannel, (_) => picked.future);
    await openSend(tester, withImage: false);
    await tester.tap(find.text('Thư viện'));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    picked.complete(imagePath);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(api.uploads, isEmpty);
  });

  testWidgets(
    'feed preserves empty/error states, retry, refresh and navigation',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            authControllerProvider.overrideWith(LocketScreenAuth.new),
          ],
          child: const MaterialApp(home: LocketFeedScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa có ảnh nào.'), findsOneWidget);
      api.feedError = const ApiException('Feed failed');
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final failedRefresh = refresh.onRefresh();
      await tester.pumpAndSettle();
      await failedRefresh;
      expect(find.text('Feed failed'), findsOneWidget);
      api.feedError = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có ảnh nào.'), findsOneWidget);
      expect(api.feedLoads, 3);
      await tester.tap(find.text('Gửi ảnh'));
      await tester.pumpAndSettle();
      expect(find.byType(SendLocketScreen), findsOneWidget);
    },
  );

  testWidgets(
    'selected recipients are required and only checked IDs are sent',
    (tester) async {
      await openSend(tester);
      await tester.ensureVisible(find.text('Gửi tất cả bạn bè'));
      await tester.tap(find.text('Gửi tất cả bạn bè'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(sendButton());
      expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('recipient-friend-2')),
      );
      await tester.tap(find.byKey(const ValueKey('recipient-friend-2')));
      await tester.pumpAndSettle();
      await startSend(tester);
      await tester.pumpAndSettle();
      expect(api.signals.single.data['recipientIds'], ['friend-2']);
      expect(api.signals.single.data['allFriends'], isFalse);
    },
  );

  testWidgets('friend loading errors block sends and a retry recovers', (
    tester,
  ) async {
    api.friendsError = const ApiException('Friends failed');
    await openSend(tester);
    await tester.ensureVisible(sendButton());
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);
    expect(find.text('Friends failed'), findsOneWidget);
    api.friendsError = null;
    await tester.ensureVisible(find.text('Tải lại bạn bè'));
    await tester.tap(find.text('Tải lại bạn bè'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(sendButton());
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNotNull);
  });

  testWidgets('empty or removed friends cannot receive a new upload', (
    tester,
  ) async {
    final container = await openSend(tester);
    await tester.ensureVisible(find.text('Gửi tất cả bạn bè'));
    await tester.tap(find.text('Gửi tất cả bạn bè'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('recipient-friend-1')),
    );
    await tester.tap(find.byKey(const ValueKey('recipient-friend-1')));
    await tester.pumpAndSettle();
    api.friends = [];
    container.invalidate(friendsProvider('friends'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(sendButton());
    expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);
    expect(api.uploads, isEmpty);
  });

  testWidgets(
    'uncertain send retries the same private upload without uploading twice',
    (tester) async {
      api.signalError = const ApiException('Timeout', isUncertain: true);
      await openSend(tester);
      await startSend(tester);
      await tester.pumpAndSettle();
      expect(api.uploads, hasLength(1));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      final first = Map.of(api.signals.single.data);
      api.signalError = null;
      await startSend(tester);
      await tester.pumpAndSettle();
      expect(api.uploads, hasLength(1));
      expect(api.signals.last.data, first);
      expect(navigationResult, isTrue);
    },
  );

  testWidgets('logout during upload prevents a send with another session', (
    tester,
  ) async {
    api.pendingUpload = Completer();
    final container = await openSend(tester);
    await startSend(tester);
    (container.read(authControllerProvider.notifier) as LocketScreenAuth)
        .signOutForTest();
    api.pendingUpload!.complete({'mediaId': 'media-1'});
    await tester.pumpAndSettle();
    expect(api.signals, isEmpty);
    expect(find.text('Vui lòng đăng nhập lại.'), findsOneWidget);
  });

  testWidgets(
    'feed loads private image bytes and reactions alongside the friends tab',
    (tester) async {
      api.privateImage = true;
      api.imageBytes = Uint8List.fromList([
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
        0,
        0,
        13,
        73,
        72,
        68,
        82,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
        8,
        6,
        0,
        0,
        0,
        31,
        21,
        196,
        137,
        0,
        0,
        0,
        11,
        73,
        68,
        65,
        84,
        120,
        156,
        99,
        96,
        0,
        2,
        0,
        0,
        5,
        0,
        1,
        165,
        246,
        69,
        64,
        0,
        0,
        0,
        0,
        73,
        69,
        78,
        68,
        174,
        66,
        96,
        130,
      ]);
      api.signals.add((path: '/locket/send-signal', data: {}));
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            authControllerProvider.overrideWith(LocketScreenAuth.new),
          ],
          child: const MaterialApp(home: LocketFeedScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PrivateLocketImage), findsOneWidget);
      expect(api.imageLoads, 1);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('10/11/2026 10:00'), findsOneWidget);
      await tester.tap(find.byTooltip('Reaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();
      expect(api.reactionCalls, ['❤️']);
      expect(find.text('❤️ Me'), findsOneWidget);
      await tester.tap(find.byTooltip('Reaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🔥'));
      await tester.pumpAndSettle();
      expect(find.text('🔥 Me'), findsOneWidget);
      await tester.tap(find.byTooltip('Reaction'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa reaction'));
      await tester.pumpAndSettle();
      expect(api.reactionCalls.last, isNull);
      expect(find.text('🔥 Me'), findsNothing);
      await tester.tap(find.widgetWithText(Tab, 'Bạn bè'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
        findsOneWidget,
      );
      expect(find.widgetWithText(Tab, 'Đã gửi'), findsNothing);
      expect(find.widgetWithText(Tab, 'Đã nhận'), findsNothing);
      expect(find.text('Gửi ảnh'), findsNothing);
      expect(
        api.loadedPaths.where((path) => path.startsWith('/locket/history')),
        isEmpty,
      );
      await tester.tap(find.widgetWithText(Tab, 'Bảng tin'));
      await tester.pumpAndSettle();
      expect(find.byType(PrivateLocketImage), findsOneWidget);
      expect(api.imageLoads, 1);
      expect(api.feedLoads, 1);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LocketFeedScreen)),
      );
      (container.read(authControllerProvider.notifier) as LocketScreenAuth)
          .signOutForTest();
      await tester.pumpAndSettle();
      expect(find.byType(PrivateLocketImage), findsNothing);
      expect(find.text('Test User'), findsNothing);
    },
  );

  testWidgets(
    'Locket friends tab searches full names and sends a request directly',
    (tester) async {
      api.friends = [
        {
          'id': 'friend-1',
          'fullName': 'Hầu Văn Hòa',
          'username': null,
          'relationship': 'FRIEND',
        },
      ];
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            authControllerProvider.overrideWith(LocketScreenAuth.new),
          ],
          child: const MaterialApp(home: LocketFeedScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Tab), findsNWidgets(2));
      await tester.tap(find.widgetWithText(Tab, 'Bạn bè'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Username (không bắt buộc)'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
        'Văn Hòa',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Hầu Văn Hòa'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Kết bạn'));
      await tester.pumpAndSettle();
      expect(api.friendRequests, ['friend-1']);
      expect(find.text('Hủy lời mời'), findsOneWidget);
      await tester.tap(find.byTooltip('Xóa tìm kiếm'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ChoiceChip, 'Bạn bè'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Lời mời nhận'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Lời mời gửi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
