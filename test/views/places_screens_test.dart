import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/places/explore_screen.dart';
import 'package:travel_trust_network_mobile/features/places/place_detail_screen.dart';
import 'package:travel_trust_network_mobile/features/places/place_model.dart';
import 'package:travel_trust_network_mobile/features/places/place_providers.dart';
import 'package:travel_trust_network_mobile/features/places/place_service.dart';
import 'package:travel_trust_network_mobile/features/reviews/create_review_screen.dart';
import 'package:travel_trust_network_mobile/features/reviews/review_model.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_screen.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_service.dart';

class TestPlaceService extends PlaceService {
  TestPlaceService() : super(api: ApiService());

  final searches = <({String? keyword, String? category})>[];
  final detailIds = <String>[];

  static const summary = PlaceSummaryModel(
    id: 'place-1',
    name: 'FPT Campus',
    category: 'CAMPUS',
    address: 'Hoa Lac',
    averageRating: 4.5,
    verifiedReviewCount: 1,
  );

  static final detail = PlaceDetailModel(
    id: summary.id,
    name: summary.name,
    category: summary.category,
    address: summary.address,
    description: 'Campus description',
    openingHours: '07:30 - 17:30',
    latitude: 21,
    longitude: 105,
    allowedRadiusM: 500,
    averageRating: summary.averageRating,
    verifiedReviewCount: summary.verifiedReviewCount,
    reviews: [
      ReviewModel(
        id: 'review-1',
        userId: 'user-1',
        fullName: 'Test Reviewer',
        placeId: summary.id,
        visitId: 'visit-1',
        rating: 4,
        comment: 'A memorable visit',
        is360Media: false,
        isVerifiedReview: true,
        createdAt: DateTime(2026, 11, 5),
      ),
    ],
  );

  @override
  Future<List<PlaceSummaryModel>> searchPlaces({
    String? keyword,
    String? category,
  }) async {
    searches.add((keyword: keyword, category: category));
    return [summary];
  }

  @override
  Future<PlaceDetailModel> getPlaceDetail(String id) async {
    detailIds.add(id);
    return detail;
  }
}

void main() {
  late TestPlaceService service;

  setUp(() => service = TestPlaceService());
  tearDown(() => service.api.close());

  test(
    'detail family shares cache, invalidates, and disposes without listeners',
    () async {
      final container = ProviderContainer(
        overrides: [placeServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      final provider = placeDetailProvider('place-1');
      expect(provider, placeDetailProvider('place-1'));

      final first = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      final second = container.listen(
        placeDetailProvider('place-1'),
        (_, _) {},
      );
      await container.read(provider.future);
      expect(service.detailIds, ['place-1']);

      container.invalidate(provider);
      await container.read(provider.future);
      expect(service.detailIds, ['place-1', 'place-1']);

      first.close();
      second.close();
      await container.pump();
      final reopened = container.listen(provider, (_, _) {});
      await container.read(provider.future);
      expect(service.detailIds, ['place-1', 'place-1', 'place-1']);
      reopened.close();
    },
  );

  test('search family caches each query and disposes unused results', () async {
    final container = ProviderContainer(
      overrides: [placeServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final all = placesListProvider((keyword: '', category: 'ALL'));
    final filtered = placesListProvider((keyword: 'FPT', category: 'CAMPUS'));
    final first = container.listen(all, (_, _) {});
    final second = container.listen(filtered, (_, _) {});
    await container.read(all.future);
    await container.read(filtered.future);
    await container.read(all.future);
    expect(service.searches, [
      (keyword: '', category: null),
      (keyword: 'FPT', category: 'CAMPUS'),
    ]);

    first.close();
    await container.pump();
    final reopened = container.listen(all, (_, _) {});
    await container.read(all.future);
    expect(service.searches.length, 3);
    expect(service.searches.last, (keyword: '', category: null));
    second.close();
    reopened.close();
  });

  Future<void> openExplore(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeServiceProvider.overrideWithValue(service),
          visitHistoryProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: ExploreScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search keeps the 500 ms debounce, filters, and refresh query', (
    tester,
  ) async {
    await openExplore(tester);
    expect(service.searches, [(keyword: '', category: null)]);

    await tester.enterText(find.byType(TextField), '  FPT  ');
    await tester.pump(const Duration(milliseconds: 499));
    expect(service.searches.length, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(service.searches.last, (keyword: 'FPT', category: null));

    await tester.tap(find.widgetWithText(FilterChip, 'Khuôn viên (Campus)'));
    await tester.pumpAndSettle();
    expect(service.searches.last, (keyword: 'FPT', category: 'CAMPUS'));

    final beforeRefresh = service.searches.length;
    await tester.drag(find.byType(ListView), const Offset(0, 350));
    await tester.pumpAndSettle();
    expect(service.searches.length, beforeRefresh + 1);
    expect(service.searches.last, (keyword: 'FPT', category: 'CAMPUS'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Explore opens Detail, then Visit and Review with the same place',
    (tester) async {
      await openExplore(tester);
      await tester.tap(find.text('FPT Campus'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PlaceDetailScreen>(find.byType(PlaceDetailScreen))
            .placeId,
        'place-1',
      );
      expect(service.detailIds, ['place-1']);
      expect(find.text('Giờ mở cửa: 07:30 - 17:30'), findsOneWidget);
      expect(
        find.textContaining('Bán kính check-in hợp lệ: ≤ 500 mét'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('A memorable visit'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Campus description'), findsOneWidget);
      expect(find.text('Test Reviewer'), findsOneWidget);
      expect(find.text('05/11/2026'), findsOneWidget);
      expect(find.text('Đã xác thực chuyến đi qua GPS'), findsOneWidget);

      await tester.tap(find.text('Check-in tại đây'));
      await tester.pumpAndSettle();
      final visit = tester.widget<VisitScreen>(find.byType(VisitScreen));
      expect(visit.placeId, 'place-1');
      expect(visit.visitId, isNull);
      expect(visit.initialVisit, isNull);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viết đánh giá'));
      await tester.pumpAndSettle();
      final review = tester.widget<CreateReviewScreen>(
        find.byType(CreateReviewScreen),
      );
      expect(review.placeId, 'place-1');
      expect(review.placeName, 'FPT Campus');
      expect(review.initialVisitId, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
