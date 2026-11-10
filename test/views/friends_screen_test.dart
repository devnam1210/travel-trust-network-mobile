import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/user_model.dart';
import 'package:travel_trust_network_mobile/features/friends/friend_model.dart';
import 'package:travel_trust_network_mobile/features/friends/friend_service.dart';
import 'package:travel_trust_network_mobile/features/friends/friends_screen.dart';

class FriendsAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: UserModel(
      id: 'me',
      email: 'me@test.invalid',
      fullName: 'Me',
      username: 'mine',
      trustScore: 50,
      verifiedVisitCount: 0,
      trustScoreLogs: [],
    ),
  );
  @override
  Future<void> refreshProfile() async {}
}

class ScreenFriends extends FriendService {
  ScreenFriends() : super(api: ApiService());
  String relationship = 'NONE';
  String fullName = 'Friend Name';
  String? username = 'friend_name';
  final searchCalls = <String>[];
  Object? error;
  final actions = <String>[];
  Completer<void>? pendingRequest;
  Completer<List<FriendUser>>? pendingSearch;
  FriendUser get person => FriendUser(
    id: 'friend',
    fullName: fullName,
    username: username,
    relationshipId: relationship == 'NONE' ? null : 'relation',
    relationship: relationship,
  );
  @override
  Future<List<FriendUser>> list([String kind = 'friends']) async {
    if (error != null) throw error!;
    final expected = {
      'friends': 'FRIEND',
      'incoming': 'INCOMING',
      'outgoing': 'OUTGOING',
    }[kind];
    return relationship == expected ? [person] : [];
  }

  @override
  Future<List<FriendUser>> search(String username) async {
    searchCalls.add(username);
    if (pendingSearch != null) return pendingSearch!.future;
    if (error != null) throw error!;
    return [person];
  }

  @override
  Future<void> request(String target) async {
    actions.add('request:$target');
    await pendingRequest?.future;
    relationship = 'OUTGOING';
  }

  @override
  Future<void> accept(String id) async {
    actions.add('accept:$id');
    relationship = 'FRIEND';
  }

  @override
  Future<void> remove(String id, String action) async {
    actions.add('$action:$id');
    relationship = 'NONE';
  }

  @override
  Future<String> updateUsername(String username) async {
    actions.add('username:$username');
    if (error != null) throw error!;
    return username;
  }
}

void main() {
  late ScreenFriends service;
  setUp(() => service = ScreenFriends());
  tearDown(() => service.api.close());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          friendServiceProvider.overrideWithValue(service),
          authControllerProvider.overrideWith(FriendsAuth.new),
        ],
        child: const MaterialApp(home: FriendsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
      'friend',
    );
    await tester.tap(find.byTooltip('Tìm kiếm'));
    await tester.pumpAndSettle();
  }

  testWidgets('find, request and cancel update the visible relationship', (
    tester,
  ) async {
    await open(tester);
    await search(tester);
    await tester.tap(find.text('Kết bạn'));
    await tester.pumpAndSettle();
    expect(service.actions, ['request:friend']);
    expect(find.text('Hủy lời mời'), findsOneWidget);
    await tester.tap(find.text('Hủy lời mời'));
    await tester.pumpAndSettle();
    expect(service.actions.last, 'cancel:relation');
    expect(find.text('Kết bạn'), findsOneWidget);
  });

  testWidgets(
    'typing a full name finds and adds an account without a username',
    (tester) async {
      service.fullName = 'Hầu Văn Hòa';
      service.username = null;
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
        '  Văn Hòa  ',
      );
      await tester.pump(const Duration(milliseconds: 349));
      expect(service.searchCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(service.searchCalls, ['Văn Hòa']);
      expect(find.text('Hầu Văn Hòa'), findsOneWidget);
      expect(find.text('@chưa đặt username'), findsNothing);
      await tester.tap(find.text('Kết bạn'));
      await tester.pumpAndSettle();
      expect(service.actions, ['request:friend']);
    },
  );

  testWidgets('clearing search hides results and does not list all users', (
    tester,
  ) async {
    await open(tester);
    await search(tester);
    final previousCalls = service.searchCalls.length;
    await tester.enterText(
      find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
      '  ',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Tìm kiếm'));
    await tester.pumpAndSettle();
    expect(service.searchCalls.length, previousCalls);
    expect(find.text('Friend Name'), findsNothing);
    expect(find.text('Chưa có người dùng nào.'), findsOneWidget);
  });

  testWidgets(
    'editing the name ignores an older response before the next search starts',
    (tester) async {
      final oldRequest = Completer<List<FriendUser>>();
      service.pendingSearch = oldRequest;
      await open(tester);
      final input = find.widgetWithText(TextField, 'Tìm bạn theo họ và tên');
      await tester.enterText(input, 'Old name');
      await tester.pump(const Duration(milliseconds: 350));
      expect(service.searchCalls, ['Old name']);
      await tester.enterText(input, 'New name');
      oldRequest.complete([
        const FriendUser(id: 'old', fullName: 'Old result'),
      ]);
      await tester.pump();
      expect(find.text('Old result'), findsNothing);
      service.pendingSearch = null;
      service.fullName = 'New result';
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(service.searchCalls, ['Old name', 'New name']);
      expect(find.text('New result'), findsOneWidget);
      expect(find.text('Old result'), findsNothing);
    },
  );

  testWidgets('closing before the search delay does not issue a request', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
      'Hòa',
    );
    await tester.pumpWidget(const MaterialApp(home: Text('Closed')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.searchCalls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'incoming accept, unfriend and reject use their own allowed actions',
    (tester) async {
      service.relationship = 'INCOMING';
      await open(tester);
      await search(tester);
      await tester.tap(find.text('Nhận'));
      await tester.pumpAndSettle();
      expect(service.actions.last, 'accept:relation');
      await tester.tap(find.text('Hủy kết bạn'));
      await tester.pumpAndSettle();
      expect(service.actions.last, 'unfriend:relation');
      service.relationship = 'INCOMING';
      await search(tester);
      await tester.tap(find.text('Từ chối'));
      await tester.pumpAndSettle();
      expect(service.actions.last, 'reject:relation');
    },
  );

  testWidgets(
    'request blocks double submit and safely completes after disposal',
    (tester) async {
      service.pendingRequest = Completer();
      await open(tester);
      await search(tester);
      final submit = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Kết bạn'))
          .onPressed!;
      submit();
      submit();
      await tester.pump();
      expect(service.actions, ['request:friend']);
      await tester.pumpWidget(const MaterialApp(home: Text('Closed')));
      service.pendingRequest!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search error keeps input and a later retry loads results', (
    tester,
  ) async {
    service.error = const ApiException('Search failed');
    await open(tester);
    await search(tester);
    expect(find.text('Search failed'), findsWidgets);
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
          )
          .controller!
          .text,
      'friend',
    );
    service.error = null;
    await search(tester);
    expect(find.text('Friend Name'), findsOneWidget);
  });

  testWidgets('username update and friend request filters remain accessible', (
    tester,
  ) async {
    service.relationship = 'FRIEND';
    await open(tester);
    await tester.tap(find.text('@mine'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Username'),
      'new_name',
    );
    await tester.tap(find.text('Lưu username'));
    await tester.pumpAndSettle();
    expect(service.actions, ['username:new_name']);
    expect(find.text('Đã cập nhật username'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bạn bè'));
    await tester.pumpAndSettle();
    expect(find.text('Friend Name'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lời mời gửi'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có người dùng nào.'), findsWidgets);
  });

  testWidgets(
    'search completion after disposal does not change a closed screen',
    (tester) async {
      service.pendingSearch = Completer();
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
        'friend',
      );
      await tester.tap(find.byTooltip('Tìm kiếm'));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: Text('Closed')));
      service.pendingSearch!.complete([service.person]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Friend Name'), findsNothing);
    },
  );
}
