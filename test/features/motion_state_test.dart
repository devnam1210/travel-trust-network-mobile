import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/app/main_navigation_screen.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_card.dart';
import 'package:travel_trust_network_mobile/features/locket/locket_feed_screen.dart';
import 'package:travel_trust_network_mobile/features/locket/private_locket_image.dart';
import 'package:travel_trust_network_mobile/features/places/place_model.dart';
import 'package:travel_trust_network_mobile/features/places/place_service.dart';
import 'package:travel_trust_network_mobile/features/messages/inbox_screen.dart';
import 'package:travel_trust_network_mobile/shared/motion/app_motion.dart';
import 'package:travel_trust_network_mobile/shared/widgets/motion_feedback.dart';

import '../views/locket_screens_test.dart'
    show LocketScreenApi, LocketScreenAuth;
import '../views/places_screens_test.dart' show TestPlaceService;

class MotionApi extends LocketScreenApi {
  @override
  Future<Map<String, dynamic>> get(String path) async => {'count': 0};
  @override
  Future<List<dynamic>> getList(String path) async {
    if (path.startsWith('/messages/')) {
      loadedPaths.add(path);
      return [
        {
          'id': 'chat-a',
          'peerId': 'peer-a',
          'peerName': 'Nam',
          'lastMessage': 'Chào bạn',
          'canSend': true,
          'updatedAt': '2026-11-11T12:00:00',
        },
        {
          'id': 'chat-b',
          'peerId': 'peer-b',
          'peerName': 'Huyền',
          'lastMessage': 'Hẹn gặp lại',
          'canSend': true,
          'updatedAt': '2026-11-11T11:00:00',
        },
      ];
    }
    if (path.startsWith('/visits/')) {
      loadedPaths.add(path);
      return [];
    }
    return super.getList(path);
  }
}

class MotionPlaces extends TestPlaceService {
  @override
  Future<List<PlaceSummaryModel>> searchPlaces({
    String? keyword,
    String? category,
  }) async {
    await super.searchPlaces(keyword: keyword, category: category);
    return List.generate(
      20,
      (i) => PlaceSummaryModel(
        id: 'place-$i',
        name: 'Campus $i',
        category: 'CAMPUS',
        address: 'Hòa Lạc',
        averageRating: 4.5,
        verifiedReviewCount: 1,
      ),
    );
  }
}

void main() {
  late MotionApi api;
  setUp(() => api = MotionApi()..accessToken = 'session');
  tearDown(() => api.close());

  Future<ProviderContainer> feed(WidgetTester tester) async {
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
    return ProviderScope.containerOf(
      tester.element(find.byType(LocketFeedScreen)),
    );
  }

  testWidgets(
    'bottom tabs retain search, scroll and provider requests; dispose safely mid-transition',
    (tester) async {
      final places = MotionPlaces();
      addTearDown(places.api.close);
      final user = LocketScreenAuth();
      await tester.binding.setSurfaceSize(const Size(600, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiServiceProvider.overrideWithValue(api),
            authControllerProvider.overrideWith(() => user),
            placeServiceProvider.overrideWithValue(places),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                final ref = ProviderScope.containerOf(context);
                return MainNavigationScreen(
                  user: ref.read(authControllerProvider).user!,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'campus');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(100));
      final requests = List.of(api.loadedPaths);
      final searches = places.searches.length;
      Finder tab(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      await tester.tap(tab('Locket'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.tap(tab('Khám phá'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'campus',
      );
      expect(scroll.position.pixels, closeTo(offset, 0.1));
      expect(api.loadedPaths, requests);
      expect(places.searches.length, searches);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(api.loadedPaths.where((p) => p.startsWith('/messages/')), isEmpty);
      await tester.tap(tab('Tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Nam'), findsOneWidget);
      expect(find.text('Huyền'), findsOneWidget);
      expect(find.text('Chào bạn'), findsOneWidget);
      final inboxLoads = api.loadedPaths
          .where((p) => p.startsWith('/messages/'))
          .length;
      await tester.tap(tab('Cá nhân'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(
        api.loadedPaths.where((p) => p.startsWith('/messages/')).length,
        inboxLoads,
      );
      await tester.tap(tab('Tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.text('Chào bạn'), findsOneWidget);
      expect(
        api.loadedPaths.where((p) => p.startsWith('/messages/')).length,
        inboxLoads + 1,
      );
      await tester.tap(tab('Locket'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Locket refresh retains loaded cards and scroll until backend completes',
    (tester) async {
      api.feedItems = List.generate(
        20,
        (i) => {...api.signal, 'id': 'signal-$i', 'caption': 'Ảnh $i'},
      );
      await feed(tester);
      final list = find.byKey(const PageStorageKey('locket-feed-user-1'));
      await tester.drag(list, const Offset(0, -700));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      final offset = scroll.position.pixels;
      final cardElement = tester.element(find.byType(LocketCard).first);
      api.pendingFeed = Completer<List<dynamic>>();
      final pending = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(LocketCard), findsWidgets);
      expect(tester.element(find.byType(LocketCard).first), same(cardElement));
      expect(scroll.position.pixels, closeTo(offset, 0.1));
      api.pendingFeed!.complete(api.feedItems!);
      await tester.pumpAndSettle();
      await pending;
      expect(scroll.position.pixels, closeTo(offset, 0.1));
      expect(api.feedLoads, 2);
    },
  );

  testWidgets(
    'friends search survives Locket tab changes without repeated API searches',
    (tester) async {
      await feed(tester);
      await tester.tap(find.widgetWithText(Tab, 'Bạn bè'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tìm bạn theo họ và tên'),
        'Hòa',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      final searches = api.loadedPaths
          .where((p) => p.startsWith('/friends/search'))
          .length;
      await tester.tap(find.widgetWithText(Tab, 'Bảng tin'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Bạn bè'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hòa',
      );
      expect(
        api.loadedPaths.where((p) => p.startsWith('/friends/search')).length,
        searches,
      );
      expect(api.feedLoads, 1);
    },
  );

  for (final fails in [false, true]) {
    testWidgets(
      'reaction waits for confirmation, avoids duplicate calls and keeps image (fails=$fails)',
      (tester) async {
        api.privateImage = true;
        api.imageBytes = base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j1ioAAAAASUVORK5CYII=',
        );
        api.signals.add((path: '/locket/send-signal', data: {}));
        final container = await feed(tester);
        final image = tester.widget<Image>(find.byType(Image)).image;
        api.pendingReaction = Completer<Map<String, dynamic>>();
        final selected = tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .onSelected!;
        selected('❤️');
        selected('❤️');
        await tester.pump();
        expect(api.reactionCalls, ['❤️']);
        expect(find.text('❤️ Me'), findsNothing);
        if (fails) {
          api.pendingReaction!.completeError(
            const ApiException('Reaction failed'),
          );
        } else {
          api.reactions = [
            {'userId': 'user-1', 'userName': 'Me', 'emoji': '❤️'},
          ];
          api.pendingReaction!.complete(api.signal);
        }
        await tester.pumpAndSettle();
        expect(find.text(fails ? 'Reaction failed' : '❤️ Me'), findsOneWidget);
        expect(tester.widget<Image>(find.byType(Image)).image, same(image));
        expect(api.imageLoads, 1);
        expect(api.feedLoads, 1);
        (container.read(authControllerProvider.notifier) as LocketScreenAuth)
            .signOutForTest();
        await tester.pump();
        expect(find.byType(PrivateLocketImage), findsNothing);
        expect(find.byType(Image), findsNothing);
      },
    );
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'native route back preserves form and result with reduced motion=$reduced',
      (tester) async {
        final text = TextEditingController();
        addTearDown(text.dispose);
        bool? returned;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              platform: TargetPlatform.android,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {TargetPlatform.android: AppPageTransitionsBuilder()},
              ),
            ),
            builder: (_, child) => MediaQuery(
              data: MediaQueryData(disableAnimations: reduced),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextField(controller: text),
                    TextButton(
                      onPressed: () async {
                        returned = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              body: TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Quay lại'),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Tiếp'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Giữ bản nháp');
        await tester.tap(find.text('Tiếp'));
        await tester.pump();
        if (reduced) {
          await tester.pump();
          expect(find.text('Quay lại').hitTestable(), findsOneWidget);
        } else {
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Quay lại'));
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(text.text, 'Giữ bản nháp');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('outgoing action cannot receive taps while status crossfades', (
    tester,
  ) async {
    bool second = false;
    int oldCalls = 0, newCalls = 0;
    late StateSetter change;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, setState) {
              change = setState;
              return MotionSwitcher(
                child: second
                    ? TextButton(
                        key: const ValueKey('second'),
                        onPressed: () => newCalls++,
                        child: const Text('Mới'),
                      )
                    : TextButton(
                        key: const ValueKey('first'),
                        onPressed: () => oldCalls++,
                        child: const Text('Cũ'),
                      ),
              );
            },
          ),
        ),
      ),
    );
    change(() => second = true);
    await tester.pump();
    await tester.tap(find.text('Cũ'), warnIfMissed: false);
    await tester.tap(find.text('Mới'));
    expect(oldCalls, 0);
    expect(newCalls, 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
