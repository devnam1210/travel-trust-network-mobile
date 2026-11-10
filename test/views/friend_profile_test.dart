import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/user_model.dart';
import 'package:travel_trust_network_mobile/features/friends/friend_profile_screen.dart';
import 'package:travel_trust_network_mobile/features/friends/friends_screen.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_card.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_model.dart';

class ProfileAuth extends AuthController {
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

class ProfileApi extends ApiService {
  ProfileApi() {
    accessToken = 'jwt';
  }
  final paths = <String>[];
  int count = 1;
  String caption = 'Một chuyến đi đẹp';
  Object? profileError, postsError;
  Completer<Map<String, dynamic>>? pendingProfile;
  Completer<List<dynamic>>? pendingOlder;
  Map<String, dynamic> get person => {
    'id': 'friend',
    'fullName': 'Hầu Văn Hòa',
    'relationship': 'FRIEND',
  };
  Map<String, dynamic> photoJson(int i) => {
    'id': 'photo-$i',
    'senderId': 'friend',
    'senderName': 'Hầu Văn Hòa',
    'mediaId': 'private-$i',
    'caption': '$caption $i',
    'sentAt': '2026-11-10T09:30:00',
    'is360Image': false,
  };
  @override
  Future<Map<String, dynamic>> get(String path) async {
    paths.add(path);
    if (pendingProfile != null) return pendingProfile!.future;
    if (profileError != null) throw profileError!;
    return person;
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    paths.add(path);
    if (path.startsWith('/friends')) return [person];
    if (postsError != null) throw postsError!;
    final page = int.parse(Uri.parse(path).queryParameters['page'] ?? '0');
    if (page > 0 && pendingOlder != null) return pendingOlder!.future;
    return List.generate(count, (i) => photoJson(i));
  }

  @override
  Future<Uint8List> getPrivateImage(String mediaId) async => Uint8List(0);
}

void main() {
  late ProfileApi api;
  setUp(() => api = ProfileApi());
  tearDown(() => api.close());
  Future<ProviderContainer> open(
    WidgetTester tester,
    Widget home, {
    bool settle = true,
  }) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          authControllerProvider.overrideWith(ProfileAuth.new),
        ],
        child: MaterialApp(home: home),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  testWidgets('tapping a friend opens shared photos with date and time', (
    tester,
  ) async {
    await open(tester, const Scaffold(body: FriendsScreen(embedded: true)));
    await tester.tap(find.text('Hầu Văn Hòa'));
    await tester.pumpAndSettle();
    expect(find.byType(FriendProfileScreen), findsOneWidget);
    expect(find.text('Ảnh đã chia sẻ với bạn'), findsOneWidget);
    expect(find.text('Một chuyến đi đẹp 0'), findsOneWidget);
    expect(find.text('10/11/2026 09:30'), findsOneWidget);
    expect(api.paths, contains('/friends/users/friend/profile'));
    expect(api.paths, contains('/locket/users/friend/posts?page=0&size=20'));
    final header = find.descendant(
      of: find.byType(LocketCard),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(header).onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a Locket sender also opens their profile', (
    tester,
  ) async {
    await open(
      tester,
      const Scaffold(
        body: SingleChildScrollView(
          child: LocketCard(
            signal: LocketSignal(
              id: 'photo',
              senderId: 'friend',
              senderName: 'Hầu Văn Hòa',
              imageUrl: '',
              is360Image: false,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Hầu Văn Hòa'));
    await tester.pumpAndSettle();
    expect(find.byType(FriendProfileScreen), findsOneWidget);
    expect(
      api.paths.where((p) => p == '/friends/users/friend/profile'),
      hasLength(1),
    );
  });

  testWidgets('empty profile does not imply other private photos are visible', (
    tester,
  ) async {
    api.count = 0;
    await open(tester, const FriendProfileScreen(userId: 'friend'));
    expect(find.text('Hầu Văn Hòa'), findsOneWidget);
    expect(find.text('Chưa có ảnh Locket nào để hiển thị.'), findsOneWidget);
    expect(find.byType(LocketCard), findsNothing);
  });

  testWidgets('profile errors can retry and refresh updates posts', (
    tester,
  ) async {
    api.profileError = const ApiException(
      'Không tìm thấy người dùng',
      statusCode: 404,
    );
    await open(tester, const FriendProfileScreen(userId: 'friend'));
    expect(find.text('Không tìm thấy người dùng'), findsOneWidget);
    api.profileError = null;
    api.postsError = const ApiException('Không tải được ảnh');
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được ảnh'), findsOneWidget);
    api.postsError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Một chuyến đi đẹp 0'), findsOneWidget);
    api.caption = 'Ảnh mới';
    await tester.tap(find.byTooltip('Làm mới hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Ảnh mới 0'), findsOneWidget);
    expect(find.text('Một chuyến đi đẹp 0'), findsNothing);
  });

  testWidgets('older shared photos paginate and double load is blocked', (
    tester,
  ) async {
    api.count = 20;
    api.pendingOlder = Completer();
    await open(tester, const FriendProfileScreen(userId: 'friend'));
    await tester.scrollUntilVisible(
      find.text('Xem ảnh cũ hơn'),
      650,
      scrollable: find.byType(Scrollable).first,
    );
    final load = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Xem ảnh cũ hơn'))
        .onPressed!;
    load();
    load();
    await tester.pump();
    expect(api.paths.where((p) => p.contains('page=1')), hasLength(1));
    api.pendingOlder!.complete([api.photoJson(20)]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Một chuyến đi đẹp 20'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Một chuyến đi đẹp 20'), findsOneWidget);
    expect(find.text('Xem ảnh cũ hơn'), findsNothing);
  });

  testWidgets('logout hides photos and late profile responses are ignored', (
    tester,
  ) async {
    final container = await open(
      tester,
      const FriendProfileScreen(userId: 'friend'),
    );
    (container.read(authControllerProvider.notifier) as ProfileAuth).expire();
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng đăng nhập lại.'), findsOneWidget);
    expect(find.byType(LocketCard), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.pendingProfile = Completer();
    await open(
      tester,
      const FriendProfileScreen(userId: 'friend'),
      settle: false,
    );
    await tester.pumpWidget(const SizedBox());
    api.pendingProfile!.completeError(const ApiException('Late error'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
