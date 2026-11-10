import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/user_model.dart';
import 'package:travel_trust_network_mobile/features/places/place_model.dart';
import 'package:travel_trust_network_mobile/features/places/place_providers.dart';
import 'package:travel_trust_network_mobile/features/reviews/create_review_screen.dart';
import 'package:travel_trust_network_mobile/features/reviews/review_service.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_model.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_screen.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_service.dart';

class ReviewScreenApi extends ApiService {
  final requests = <({String path, Map<String, dynamic> data})>[];
  Completer<Map<String, dynamic>>? pending;
  Object? error;

  Map<String, dynamic> response(Map<String, dynamic> data) => {
    'id': 'review-1',
    'userId': 'user-1',
    'fullName': 'Test User',
    ...data,
    'isVerifiedReview': true,
    'createdAt': '2026-11-05T10:00:00',
  };

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    requests.add((path: path, data: Map<String, dynamic>.of(data)));
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return response(data);
  }
}

class ReviewScreenAuthController extends AuthController {
  int profileRefreshes = 0;
  Completer<void>? pendingRefresh;

  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: UserModel(
      id: 'user-1',
      email: 'test@example.com',
      fullName: 'Test User',
      trustScore: 0,
      verifiedVisitCount: 2,
      trustScoreLogs: [],
    ),
  );

  @override
  Future<void> refreshProfile() async {
    profileRefreshes++;
    await pendingRefresh?.future;
  }
}

VisitModel visit(
  String id, {
  String placeId = 'place-1',
  String status = 'VERIFIED',
  int day = 5,
}) => VisitModel(
  id: id,
  placeId: placeId,
  placeName: 'FPT Campus',
  status: status,
  checkInTime: DateTime(2026, 11, day, 9),
  checkOutTime: DateTime(2026, 11, day, 10),
);

void main() {
  late ReviewScreenApi api;
  int historyLoads = 0;
  int detailLoads = 0;
  bool? navigationResult;
  const place = PlaceDetailModel(
    id: 'place-1',
    name: 'FPT Campus',
    category: 'CAMPUS',
    address: 'Hoa Lac',
    latitude: 21,
    longitude: 105,
    allowedRadiusM: 500,
  );

  setUp(() {
    api = ReviewScreenApi();
    historyLoads = 0;
    detailLoads = 0;
    navigationResult = null;
  });
  tearDown(() => api.close());

  Future<ProviderContainer> openReview(
    WidgetTester tester, {
    List<VisitModel>? visits,
    Future<List<VisitModel>>? historyFuture,
    Future<List<VisitModel>> Function()? loadHistory,
    String? initialVisitId,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          reviewServiceProvider.overrideWithValue(ReviewService(api: api)),
          authControllerProvider.overrideWith(ReviewScreenAuthController.new),
          visitHistoryProvider.overrideWith((ref) {
            historyLoads++;
            return loadHistory?.call() ??
                historyFuture ??
                Future.value(
                  visits ??
                      [
                        visit('visit-1'),
                        visit('visit-2', day: 6),
                        visit('open-visit', status: 'OPEN'),
                        visit('other-place', placeId: 'place-2'),
                      ],
                );
          }),
          placeDetailProvider.overrideWith((ref, id) async {
            detailLoads++;
            return place;
          }),
          visitPlaceProvider.overrideWith((ref, id) async => place),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  navigationResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) => CreateReviewScreen(
                        placeId: place.id,
                        placeName: place.name,
                        initialVisitId: initialVisitId,
                      ),
                    ),
                  );
                },
                child: const Text('Open review'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(CreateReviewScreen)),
    );
  }

  Finder commentField() => find.byType(TextFormField).at(0);
  Finder imageField() => find.byType(TextFormField).at(1);
  Finder submitButton() => find.widgetWithText(FilledButton, 'Đăng đánh giá');
  Finder ratingButtons() => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.iconSize == 42,
  );

  Future<void> enterComment(WidgetTester tester, String text) async {
    await tester.ensureVisible(commentField());
    await tester.enterText(commentField(), text);
  }

  Future<void> selectVisit2(WidgetTester tester) async {
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyến đi ngày 6/11/2026 10:00').last);
    await tester.pumpAndSettle();
  }

  Future<void> selectRating(WidgetTester tester, int rating) async {
    final button = ratingButtons().at(rating - 1);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(submitButton());
    await tester.tap(submitButton());
    await tester.pump();
  }

  Future<void> fillDraft(WidgetTester tester) async {
    await selectRating(tester, 2);
    await enterComment(tester, 'Review draft');
    await tester.ensureVisible(imageField());
    await tester.enterText(imageField(), '/uploads/draft.png');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
  }

  void expectDraft(WidgetTester tester) {
    expect(
      tester.widget<TextFormField>(commentField()).controller!.text,
      'Review draft',
    );
    expect(
      tester.widget<TextFormField>(imageField()).controller!.text,
      '/uploads/draft.png',
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(find.text('Tạm được'), findsOneWidget);
  }

  void expectSelectedVisit(WidgetTester tester, String id) {
    final dropdown = find.byType(DropdownButtonFormField<String>);
    expect(
      tester.widget<DropdownButtonFormField<String>>(dropdown).initialValue,
      id,
    );
    expect(tester.state<FormFieldState<String>>(dropdown).value, id);
    expect(tester.takeException(), isNull);
  }

  Future<void> reloadHistory(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    container.invalidate(visitHistoryProvider);
    await tester.pumpAndSettle();
  }

  testWidgets('filters VERIFIED visits and submits selected form data once', (
    tester,
  ) async {
    final container = await openReview(tester);
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );
    final options = tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .items!;
    expect(options.map((item) => item.value), ['visit-1', 'visit-2']);
    expect(dropdown.initialValue, 'visit-1');

    final detailSubscription = container.listen(
      placeDetailProvider('place-1'),
      (_, _) {},
    );
    final historySubscription = container.listen(
      visitHistoryProvider,
      (_, _) {},
    );
    addTearDown(detailSubscription.close);
    addTearDown(historySubscription.close);
    await container.read(placeDetailProvider('place-1').future);
    final auth = container.read(
      authControllerProvider.notifier,
    ) as ReviewScreenAuthController;

    await selectVisit2(tester);
    await selectRating(tester, 3);
    await enterComment(tester, '  A memorable visit  ');
    await tester.ensureVisible(imageField());
    await tester.enterText(imageField(), '  /uploads/postcard.png  ');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    api.pending = Completer<Map<String, dynamic>>();
    await submit(tester);

    expect(api.requests, hasLength(1));
    expect(api.requests.single.path, '/reviews');
    expect(api.requests.single.data, {
      'visitId': 'visit-2',
      'placeId': 'place-1',
      'rating': 3,
      'comment': 'A memorable visit',
      'postcardImageUrl': '/uploads/postcard.png',
      'is360Media': true,
    });
    expect(find.text('Đang gửi đánh giá…'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Đang gửi đánh giá…'),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(auth.profileRefreshes, 0);

    api.pending!.complete(api.response(api.requests.single.data));
    await tester.pumpAndSettle();
    expect(auth.profileRefreshes, 1);
    expect(historyLoads, 2);
    expect(detailLoads, 2);
    expect(navigationResult, isTrue);
    expect(find.byType(CreateReviewScreen), findsNothing);
    expect(find.text('Đăng đánh giá thành công!'), findsOneWidget);
    expect(find.textContaining('+5'), findsNothing);
    expect(find.textContaining('điểm uy tín'), findsNothing);
  });

  testWidgets('empty and short comments fail validation without a request', (
    tester,
  ) async {
    await openReview(tester);
    await submit(tester);
    expect(find.text('Vui lòng nhập nội dung đánh giá.'), findsOneWidget);
    expect(api.requests, isEmpty);

    await enterComment(tester, ' abcd ');
    await submit(tester);
    expect(find.text('Nội dung nhận xét tối thiểu 5 ký tự.'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets('no eligible visit blocks submit and check-in opens same place', (
    tester,
  ) async {
    await openReview(
      tester,
      visits: [
        visit('open', status: 'OPEN'),
        visit('other', placeId: 'place-2'),
      ],
    );
    expect(find.text('Chưa có chuyến đi hoàn tất'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await enterComment(tester, 'A valid comment');
    await submit(tester);
    expect(
      find.text(
        'Vui lòng chọn chuyến đi đã xác thực để liên kết với đánh giá.',
      ),
      findsOneWidget,
    );
    expect(api.requests, isEmpty);

    await tester.ensureVisible(find.text('Check-in ngay'));
    await tester.tap(find.text('Check-in ngay'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<VisitScreen>(find.byType(VisitScreen)).placeId,
      'place-1',
    );
  });

  testWidgets('keeps initial visit and sends ratings 1 and 5 with null image', (
    tester,
  ) async {
    await openReview(tester, initialVisitId: 'visit-2');
    api.error = const ApiException('Keep form open');
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .initialValue,
      'visit-2',
    );
    await enterComment(tester, 'Valid review');
    for (final rating in [1, 5]) {
      await selectRating(tester, rating);
      expect(find.text(rating == 1 ? 'Rất tệ' : 'Tuyệt vời!'), findsOneWidget);
      await submit(tester);
      expect(api.requests.last.data['rating'], rating);
      expect(api.requests.last.data['visitId'], 'visit-2');
      expect(api.requests.last.data['postcardImageUrl'], isNull);
      expect(api.requests.last.data['is360Media'], isFalse);
    }
  });

  testWidgets(
    'submit errors preserve visit, rating, comment, URL and 360 flag',
    (tester) async {
      await openReview(tester);
      await selectVisit2(tester);
      await selectRating(tester, 2);
      await enterComment(tester, 'Review draft');
      await tester.ensureVisible(imageField());
      await tester.enterText(imageField(), '/uploads/draft.png');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));

      final errors = <({Object error, String message})>[
        (
          error: const ApiException('Duplicate', code: 'DUPLICATE_REVIEW'),
          message: 'Bạn đã từng gửi đánh giá cho địa điểm này rồi (Mỗi người dùng chỉ được đánh giá 1 lần).',
        ),
        (
          error: const ApiException('Unverified', code: 'UNVERIFIED_VISIT'),
          message: 'Chuyến đi này chưa hoàn tất Check-out (chưa đạt trạng thái VERIFIED).',
        ),
        (
          error: const ApiException('Server message'),
          message: 'Server message',
        ),
        (
          error: FormatException('Bad response'),
          message: 'Không thể gửi đánh giá: FormatException: Bad response',
        ),
      ];
      for (final scenario in errors) {
        api.error = scenario.error;
        await submit(tester);
        expect(find.text(scenario.message), findsOneWidget);
        expect(
          tester.widget<TextFormField>(commentField()).controller!.text,
          'Review draft',
        );
        expect(
          tester.widget<TextFormField>(imageField()).controller!.text,
          '/uploads/draft.png',
        );
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )
              .initialValue,
          'visit-2',
        );
        expect(
          tester.widget<FilledButton>(submitButton()).onPressed,
          isNotNull,
        );
        expect(api.requests.last.data['rating'], 2);
        expect(navigationResult, isNull);
      }
      expect(api.requests, hasLength(errors.length));
    },
  );

  testWidgets('history loading and error keep the current comment draft', (
    tester,
  ) async {
    final history = Completer<List<VisitModel>>();
    await openReview(tester, historyFuture: history.future);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await enterComment(tester, 'Draft while loading');

    history.completeError(const ApiException('History unavailable'));
    await tester.pumpAndSettle();
    expect(
      find.text('Không thể tải lịch sử chuyến đi để kiểm tra.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextFormField>(commentField()).controller!.text,
      'Draft while loading',
    );
    expect(api.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final outcome in ['success', 'API error', 'parse error']) {
    testWidgets(
      'ignores $outcome after disposal while review request is pending',
      (tester) async {
        final container = await openReview(tester);
        final auth = container.read(
          authControllerProvider.notifier,
        ) as ReviewScreenAuthController;
        await enterComment(tester, 'Valid review');
        api.pending = Completer<Map<String, dynamic>>();
        await submit(tester);
        expect(api.requests, hasLength(1));

        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        expect(find.byType(CreateReviewScreen), findsNothing);

        if (outcome == 'success') {
          api.pending!.complete(api.response(api.requests.single.data));
        } else {
          api.pending!.completeError(
            outcome == 'API error'
                ? const ApiException('Late failure', code: 'DUPLICATE_REVIEW')
                : const FormatException('Late parse failure'),
          );
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(auth.profileRefreshes, 0);
        expect(find.text('Open review'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(navigationResult, isNull);
      },
    );
  }

  for (final fails in [false, true]) {
    testWidgets(
      'ignores profile refresh completion after disposal (fails=$fails)',
      (tester) async {
        final container = await openReview(tester);
        final auth = container.read(
          authControllerProvider.notifier,
        ) as ReviewScreenAuthController;
        auth.pendingRefresh = Completer<void>();
        await enterComment(tester, 'Valid review');
        await submit(tester);
        expect(auth.profileRefreshes, 1);
        expect(find.text('Đang gửi đánh giá…'), findsOneWidget);

        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
        if (fails) {
          auth.pendingRefresh!.completeError(
            const ApiException('Late profile error'),
          );
        } else {
          auth.pendingRefresh!.complete();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Open review'), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(navigationResult, isNull);
      },
    );
  }

  testWidgets('keeps a valid selection after asynchronous history reordering', (
    tester,
  ) async {
    var nextHistory = Future.value([
      visit('visit-1'),
      visit('visit-2', day: 6),
    ]);
    final container = await openReview(
      tester,
      initialVisitId: 'visit-2',
      loadHistory: () => nextHistory,
    );
    await fillDraft(tester);
    final pending = Completer<List<VisitModel>>();
    nextHistory = pending.future;
    container.invalidate(visitHistoryProvider);
    await tester.pump();
    expect(container.read(visitHistoryProvider).isLoading, isTrue);

    pending.complete([visit('visit-2', day: 6), visit('visit-1')]);
    await tester.pumpAndSettle();
    expectSelectedVisit(tester, 'visit-2');
    expectDraft(tester);
    expect(api.requests, isEmpty);
    expect(historyLoads, 2);
  });

  for (final reason in ['disappears', 'becomes OPEN']) {
    testWidgets('selects the first eligible visit when selection $reason', (
      tester,
    ) async {
      var visits = [visit('visit-1'), visit('visit-2', day: 6)];
      final container = await openReview(
        tester,
        initialVisitId: 'visit-2',
        loadHistory: () async => visits,
      );
      await fillDraft(tester);
      visits = [
        visit('visit-3', day: 7),
        if (reason == 'becomes OPEN') visit('visit-2', status: 'OPEN', day: 6),
        visit('visit-1'),
      ];
      await reloadHistory(tester, container);
      expectSelectedVisit(tester, 'visit-3');
      expectDraft(tester);

      api.error = const ApiException('Keep form open');
      await submit(tester);
      expect(api.requests.single.data['visitId'], 'visit-3');
      expect(api.requests.single.data['rating'], 2);
      expect(api.requests.single.data['comment'], 'Review draft');
      expect(
        api.requests.single.data['postcardImageUrl'],
        '/uploads/draft.png',
      );
      expect(api.requests.single.data['is360Media'], isTrue);
    });
  }

  testWidgets(
    'empty eligible history resets selection and preserves other fields',
    (tester) async {
      var visits = [visit('visit-1'), visit('visit-2', day: 6)];
      final container = await openReview(
        tester,
        initialVisitId: 'visit-2',
        loadHistory: () async => visits,
      );
      await fillDraft(tester);
      visits = [
        visit('visit-2', status: 'OPEN'),
        visit('other', placeId: 'place-2'),
      ];
      await reloadHistory(tester, container);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Chưa có chuyến đi hoàn tất'), findsOneWidget);
      expectDraft(tester);
      await submit(tester);
      expect(api.requests, isEmpty);

      // Returning visits start a new selection instead of resurrecting the old ID.
      visits = [visit('visit-3', day: 7), visit('visit-2', day: 6)];
      await reloadHistory(tester, container);
      expectSelectedVisit(tester, 'visit-3');
      expectDraft(tester);
    },
  );

  testWidgets('invalid initial visit falls back to the first VERIFIED visit', (
    tester,
  ) async {
    await openReview(tester, initialVisitId: 'missing-visit');
    expectSelectedVisit(tester, 'visit-1');
    api.error = const ApiException('Keep form open');
    await enterComment(tester, 'Valid review');
    await submit(tester);
    expect(api.requests.single.data['visitId'], 'visit-1');
  });

  testWidgets('rechecks history at submit before a pending UI rebuild', (
    tester,
  ) async {
    var visits = [visit('visit-1'), visit('visit-2', day: 6)];
    final container = await openReview(
      tester,
      initialVisitId: 'visit-2',
      loadHistory: () async => visits,
    );
    await enterComment(tester, 'Valid review');
    await tester.ensureVisible(submitButton());
    final onSubmit = tester.widget<FilledButton>(submitButton()).onPressed!;
    visits = [visit('visit-1')];
    container.invalidate(visitHistoryProvider);
    await container.read(visitHistoryProvider.future);

    // The old button still exists until the next frame, but its visit is stale.
    onSubmit();
    await tester.pumpAndSettle();
    expect(api.requests, isEmpty);
    expectSelectedVisit(tester, 'visit-1');
    expect(
      find.text(
        'Vui lòng chọn chuyến đi đã xác thực để liên kết với đánh giá.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blocks stale selection during reload and after history errors', (
    tester,
  ) async {
    var nextHistory = Future.value([
      visit('visit-1'),
      visit('visit-2', day: 6),
    ]);
    final container = await openReview(
      tester,
      initialVisitId: 'visit-2',
      loadHistory: () => nextHistory,
    );
    await fillDraft(tester);
    final pending = Completer<List<VisitModel>>();
    nextHistory = pending.future;
    container.invalidate(visitHistoryProvider);
    await tester.pump();
    await submit(tester);
    expect(api.requests, isEmpty);

    pending.completeError(const ApiException('History failed'));
    await tester.pumpAndSettle();
    await submit(tester);
    expect(api.requests, isEmpty);
    expect(
      find.text('Không thể tải lịch sử chuyến đi để kiểm tra.'),
      findsOneWidget,
    );
    expectDraft(tester);

    nextHistory = Future.value([visit('visit-2', day: 6), visit('visit-1')]);
    await reloadHistory(tester, container);
    expectSelectedVisit(tester, 'visit-2');
    expectDraft(tester);
  });

  testWidgets(
    'late responses from an older history reload do not restore stale visits',
    (tester) async {
      var nextHistory = Future.value([
        visit('visit-1'),
        visit('visit-2', day: 6),
      ]);
      final container = await openReview(
        tester,
        initialVisitId: 'visit-2',
        loadHistory: () => nextHistory,
      );
      await fillDraft(tester);
      final older = Completer<List<VisitModel>>();
      nextHistory = older.future;
      container.invalidate(visitHistoryProvider);
      await tester.pump();
      final newer = Completer<List<VisitModel>>();
      nextHistory = newer.future;
      container.invalidate(visitHistoryProvider);
      await tester.pump();

      newer.complete([visit('visit-3', day: 7)]);
      await tester.pumpAndSettle();
      expectSelectedVisit(tester, 'visit-3');
      older.complete([visit('visit-2', day: 6)]);
      await tester.pumpAndSettle();
      expectSelectedVisit(tester, 'visit-3');
      expectDraft(tester);
      expect(historyLoads, 3);
    },
  );

  testWidgets('repeated callbacks before a rebuild only submit once', (
    tester,
  ) async {
    await openReview(tester);
    await enterComment(tester, 'Valid review');
    await tester.ensureVisible(submitButton());
    final onSubmit = tester.widget<FilledButton>(submitButton()).onPressed!;
    api.pending = Completer<Map<String, dynamic>>();
    onSubmit();
    onSubmit();
    await tester.pump();
    expect(api.requests, hasLength(1));
    api.pending!.completeError(const ApiException('Try again'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submitButton()).onPressed, isNotNull);
    expect(find.text('Try again'), findsOneWidget);
  });
}
