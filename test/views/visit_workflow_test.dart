import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/auth/auth_controller.dart';
import 'package:travel_trust_network_mobile/features/auth/user_model.dart';
import 'package:travel_trust_network_mobile/features/places/place_model.dart';
import 'package:travel_trust_network_mobile/features/reviews/create_review_screen.dart';
import 'package:travel_trust_network_mobile/features/visits/location_service.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_history_screen.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_model.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_screen.dart';
import 'package:travel_trust_network_mobile/features/visits/visit_service.dart';

Map<String, dynamic> visitJson({
  String id = 'visit-1',
  String status = 'OPEN',
}) => {
  'id': id,
  'placeId': 'place-1',
  'placeName': 'Campus',
  'status': status,
  'checkInTime': '2026-11-05T09:00:00',
  'checkOutTime': status == 'VERIFIED' ? '2026-11-05T10:00:00' : null,
  'distanceMeters': 12.5,
};

class WorkflowVisitApi extends ApiService {
  final mutations =
      <({String method, String path, Map<String, dynamic>? data})>[];
  int historyCalls = 0;
  final historyPaths = <String>[];
  List<dynamic> history = [];
  Object? mutationError;
  Object? historyError;
  Completer<Map<String, dynamic>>? pending;

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> data,
  ) async {
    mutations.add((method: 'POST', path: path, data: Map.of(data)));
    if (pending != null) return pending!.future;
    if (mutationError != null) throw mutationError!;
    return visitJson();
  }

  @override
  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    mutations.add((method: 'PUT', path: path, data: data));
    if (pending != null) return pending!.future;
    if (mutationError != null) throw mutationError!;
    return visitJson(status: 'VERIFIED');
  }

  @override
  Future<List<dynamic>> getList(String path) async {
    historyPaths.add(path);
    historyCalls++;
    if (historyError != null) throw historyError!;
    return history;
  }
}

class WorkflowAuthController extends AuthController {
  int profileRefreshes = 0;

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

  @override
  Future<void> refreshProfile() async {
    profileRefreshes++;
  }
}

class WorkflowLocationService extends LocationService {
  int calls = 0;

  @override
  Future<Position> getCurrentPosition() async {
    calls++;
    return Position(
      latitude: 21 + calls / 10000,
      longitude: 105,
      timestamp: DateTime(2026, 11, 5, 9),
      accuracy: calls == 1 ? 80 : 15,
      hasAccuracy: true,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  late WorkflowVisitApi api;
  late WorkflowLocationService location;
  const place = PlaceDetailModel(
    id: 'place-1',
    name: 'Campus',
    category: 'CAMPUS',
    address: 'Hoa Lac',
    latitude: 21,
    longitude: 105,
    allowedRadiusM: 200,
  );

  setUp(() {
    api = WorkflowVisitApi();
    location = WorkflowLocationService();
  });
  tearDown(() => api.close());

  Future<ProviderContainer> openScreen(
    WidgetTester tester, {
    VisitModel? initialVisit,
    String? visitId,
    bool historyScreen = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (retryCount, error) => null,
        overrides: [
          authControllerProvider.overrideWith(WorkflowAuthController.new),
          locationServiceProvider.overrideWithValue(location),
          visitServiceProvider.overrideWithValue(VisitService(api: api)),
          visitPlaceProvider.overrideWith((ref, id) async => place),
        ],
        child: MaterialApp(
          home: historyScreen
              ? const VisitHistoryScreen()
              : VisitScreen(
                  placeId: place.id,
                  visitId: visitId,
                  initialVisit: initialVisit,
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(
        find.byType(historyScreen ? VisitHistoryScreen : VisitScreen).first,
      ),
    );
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'preview, fresh check-in and checkout preserve payload and shared updates',
    (tester) async {
      final container = await openScreen(tester);
      await tap(tester, 'Kiểm tra GPS / Đo lại');
      expect(location.calls, 1);
      expect(api.mutations, isEmpty);
      expect(
        find.text('GPS điện thoại: 21.000100, 105.000000'),
        findsOneWidget,
      );
      expect(find.text('Sai số ước tính: ±80.0 m'), findsOneWidget);
      expect(find.textContaining('Vị trí chưa ổn định.'), findsOneWidget);

      final historySubscription = container.listen(
        visitHistoryProvider,
        (_, _) {},
      );
      addTearDown(historySubscription.close);
      await container.read(visitHistoryProvider.future);
      final auth = container.read(
        authControllerProvider.notifier,
      ) as WorkflowAuthController;
      api.pending = Completer<Map<String, dynamic>>();
      await tester.ensureVisible(find.text('Check-in'));
      final checkIn = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check-in'))
          .onPressed!;
      checkIn();
      checkIn();
      await tester.pump();
      expect(location.calls, 2);
      expect(api.mutations, hasLength(1));
      expect(api.mutations.single.method, 'POST');
      expect(api.mutations.single.path, '/visits/check-in');
      expect(api.mutations.single.data, {
        'placeId': 'place-1',
        'userLat': 21.0002,
        'userLng': 105.0,
        'gpsAccuracy': 15.0,
        'isMocked': false,
      });
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check-in'))
            .onPressed,
        isNull,
      );

      api.history = [visitJson()];
      api.pending!.complete(visitJson());
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái: OPEN'), findsOneWidget);
      expect(await container.read(visitHistoryProvider.future), hasLength(1));
      expect(api.historyCalls, 2);
      expect(auth.profileRefreshes, 0);

      api.pending = Completer<Map<String, dynamic>>();
      final checkOut = tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Check-out'))
          .onPressed!;
      checkOut();
      checkOut();
      await tester.pump();
      expect(api.mutations, hasLength(2));
      expect(api.mutations.last.method, 'PUT');
      expect(api.mutations.last.path, '/visits/visit-1/check-out');
      expect(api.mutations.last.data, isNull);
      expect(location.calls, 2);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Check-out'),
            )
            .onPressed,
        isNull,
      );

      api.history = [visitJson(status: 'VERIFIED')];
      api.pending!.complete(visitJson(status: 'VERIFIED'));
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái: VERIFIED'), findsOneWidget);
      expect(find.text('Check-out'), findsNothing);
      expect(
        (await container.read(visitHistoryProvider.future)).single.status,
        'VERIFIED',
      );
      expect(api.historyCalls, 3);
      expect(api.historyPaths, everyElement('/visits/my-history'));
      expect(auth.profileRefreshes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final error in <Object>[
    const ApiException('Response missing', isUncertain: true),
    const FormatException('Invalid mutation response'),
    const ApiException(
      'Open visit exists',
      code: 'SINGLE_OPEN_VISIT',
      statusCode: 409,
    ),
  ]) {
    testWidgets(
      'check-in stays locked until history reconciliation: ${error is ApiException ? error.code ?? 'uncertain response' : 'invalid response'}',
      (tester) async {
        api.mutationError = error;
        await openScreen(tester);
        await tap(tester, 'Check-in');
        expect(api.mutations, hasLength(1));
        expect(find.text('Check-in'), findsNothing);
        expect(find.text('Check-out'), findsNothing);
        await tester.pump(const Duration(seconds: 1));
        expect(api.mutations, hasLength(1));

        api.historyError = const ApiException(
          'History temporarily unavailable',
        );
        await tap(tester, 'Tải lại trạng thái từ lịch sử');
        expect(find.text('History temporarily unavailable'), findsOneWidget);
        expect(find.text('Check-in'), findsNothing);
        expect(find.text('Check-out'), findsNothing);
        expect(api.mutations, hasLength(1));

        api.historyError = null;
        api.history = [visitJson(id: 'existing-visit')];
        await tap(tester, 'Tải lại trạng thái từ lịch sử');
        expect(find.text('Check-out'), findsOneWidget);
        expect(api.mutations, hasLength(1));
        expect(location.calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final error in [
    const ApiException('Checkout response missing', isUncertain: true),
    const ApiException(
      'Already closed',
      code: 'ALREADY_CHECKED_OUT',
      statusCode: 409,
    ),
  ]) {
    testWidgets(
      'checkout reconciles the exact visit without retry: ${error.message}',
      (tester) async {
        api.history = [visitJson()];
        final container = await openScreen(
          tester,
          initialVisit: VisitModel.fromJson(visitJson()),
          visitId: 'visit-1',
        );
        expect(api.historyCalls, 1);
        api.mutationError = error;
        await tap(tester, 'Check-out');
        expect(find.text('Check-out'), findsNothing);
        expect(api.mutations, hasLength(1));

        api.history = [
          visitJson(id: 'unrelated-open'),
          visitJson(status: 'VERIFIED'),
        ];
        await tap(tester, 'Tải lại trạng thái từ lịch sử');
        expect(find.text('Trạng thái: VERIFIED'), findsOneWidget);
        expect(find.text('Check-out'), findsNothing);
        expect(api.mutations, hasLength(1));
        expect(location.calls, 0);
        expect(
          (container.read(
            authControllerProvider.notifier,
          ) as WorkflowAuthController).profileRefreshes,
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing known visit stays locked instead of creating another visit',
    (tester) async {
      api.history = [visitJson(id: 'other-visit')];
      await openScreen(tester, visitId: 'missing-visit');
      expect(
        find.text('Không tìm thấy chuyến đi trong lịch sử của bạn.'),
        findsOneWidget,
      );
      expect(find.text('Check-in'), findsNothing);
      expect(find.text('Check-out'), findsNothing);
      expect(api.mutations, isEmpty);
      expect(location.calls, 0);
    },
  );

  testWidgets(
    'history opens existing visits and reviews with unchanged arguments',
    (tester) async {
      api.history = [
        visitJson(),
        visitJson(id: 'verified-visit', status: 'VERIFIED'),
      ];
      await openScreen(tester, historyScreen: true);
      await tap(tester, 'Nhấn để tiếp tục Check-out →');
      final visitScreen = tester.widget<VisitScreen>(find.byType(VisitScreen));
      expect(visitScreen.placeId, 'place-1');
      expect(visitScreen.visitId, 'visit-1');
      expect(visitScreen.initialVisit!.id, 'visit-1');

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      await tap(tester, 'Viết đánh giá (+5 điểm)');
      final reviewScreen = tester.widget<CreateReviewScreen>(
        find.byType(CreateReviewScreen),
      );
      expect(reviewScreen.placeId, 'place-1');
      expect(reviewScreen.placeName, 'Campus');
      expect(reviewScreen.initialVisitId, 'verified-visit');
      expect(api.mutations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'history refresh reports errors and retry loads the same provider',
    (tester) async {
      await openScreen(tester, historyScreen: true);
      expect(api.historyCalls, 1);
      api.historyError = const ApiException('History unavailable');
      await tester.drag(find.byType(ListView), const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.text('History unavailable'), findsOneWidget);
      expect(api.historyCalls, 2);
      api.historyError = null;
      api.history = [visitJson()];
      await tap(tester, 'Thử lại');
      expect(api.historyCalls, 3);
      expect(find.text('Trạng thái: OPEN'), findsOneWidget);
      expect(api.mutations, isEmpty);
    },
  );

  test(
    'check-in preserves null accuracy and mocked flag, and encodes checkout ID',
    () async {
      final service = VisitService(api: api);
      final visit = await service.checkIn(
        placeId: 'place-1',
        userLat: 21,
        userLng: 105,
        gpsAccuracy: null,
        isMocked: true,
      );
      expect(api.mutations.single.data!['gpsAccuracy'], isNull);
      expect(api.mutations.single.data!['isMocked'], isTrue);
      expect(visit.id, 'visit-1');
      expect(visit.checkInTime, DateTime(2026, 11, 5, 9));
      await service.checkOut('visit/with space');
      expect(api.mutations.last.path, '/visits/visit%2Fwith%20space/check-out');
      expect(api.mutations.last.data, isNull);
    },
  );
}
