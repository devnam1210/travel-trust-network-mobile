import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travel_trust_network_mobile/controllers/auth_controller.dart';
import 'package:travel_trust_network_mobile/main.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/location_service.dart';
import 'package:travel_trust_network_mobile/views/auth/login_screen.dart';
import 'package:travel_trust_network_mobile/views/profile_screen.dart';
import 'package:travel_trust_network_mobile/views/visits/visit_history_screen.dart';
import 'package:travel_trust_network_mobile/views/visits/visit_screen.dart';

import 'support/auth_fakes.dart';
import 'support/visit_fakes.dart';

class FakeLocationService extends LocationService {
  int calls = 0;

  @override
  Future<Position> getCurrentPosition() async {
    calls++;
    return Position(
      latitude: 21.0124,
      longitude: 105.5253,
      timestamp: DateTime(2026, 11, 4),
      accuracy: 8.5,
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
  late FakeBackend backend;
  late ApiService api;
  late MemoryTokenStorage storage;
  late FakeLocationService location;
  String? visitStatus;
  bool historyFails = false;
  FutureOr<ResponseBody> Function(RequestOptions)? mutation;

  setUp(() {
    backend = FakeBackend();
    api = ApiService(dio: Dio()..httpClientAdapter = backend);
    storage = MemoryTokenStorage()..token = 'saved-jwt';
    location = FakeLocationService();
    visitStatus = null;
    historyFails = false;
    mutation = null;
    backend.respond = (options) {
      if (options.path == '/users/me/profile') {
        return apiResponse(profileJson());
      }
      if (options.path == '/visits/my-history') {
        if (historyFails) {
          return apiResponse(null, status: 503, message: 'Mất kết nối lịch sử');
        }
        return apiResponse(
          visitStatus == null ? [] : [visitJson(status: visitStatus!)],
        );
      }
      if (mutation != null) return mutation!(options);
      visitStatus = options.method == 'POST' ? 'OPEN' : 'VERIFIED';
      return apiResponse(visitJson(status: visitStatus!));
    };
  });
  tearDown(() => api.close());

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          tokenStorageProvider.overrideWithValue(storage),
          locationServiceProvider.overrideWithValue(location),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Navigator.of(tester.element(find.byType(ProfileScreen)))
          .push(MaterialPageRoute<void>(builder: (_) => screen)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'check-in opens a visit; check-out displays backend status and time',
    (tester) async {
      await open(
        tester,
        VisitScreen(placeId: visitJson()['placeId'] as String),
      );
      expect(location.calls, 0);
      await tap(tester, 'Check-in');
      expect(find.text('Trạng thái: OPEN'), findsOneWidget);
      await tap(tester, 'Check-out');
      expect(find.text('Trạng thái: VERIFIED'), findsOneWidget);
      expect(find.text('Check-out: 04/11/2026 10:00:00'), findsOneWidget);
      expect(find.text('Check-out'), findsNothing);
      expect(location.calls, 1);
    },
  );

  testWidgets('timeout hides check-out until history confirms the result', (
    tester,
  ) async {
    visitStatus = 'OPEN';
    await open(tester, const VisitHistoryScreen());
    await tap(tester, 'Địa điểm kiểm thử');
    mutation = (options) {
      visitStatus = 'VERIFIED';
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    };
    await tap(tester, 'Check-out');
    expect(find.textContaining('backend có thể đã xử lý'), findsOneWidget);
    expect(find.text('Check-out'), findsNothing);
    await tap(tester, 'Tải lại trạng thái từ lịch sử');
    expect(find.text('Trạng thái: VERIFIED'), findsOneWidget);
    expect(
      backend.requests.where((request) => request.method == 'PUT'),
      hasLength(1),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Trạng thái: VERIFIED'), findsOneWidget);
  });

  testWidgets(
    'history shows empty/error states and pull-to-refresh loads visits',
    (tester) async {
      historyFails = true;
      await open(tester, const VisitHistoryScreen());
      expect(find.text('Mất kết nối lịch sử'), findsOneWidget);
      historyFails = false;
      await tap(tester, 'Thử lại');
      expect(find.textContaining('Bạn chưa có chuyến đi nào'), findsOneWidget);
      visitStatus = 'OPEN';
      await tester.drag(find.byType(ListView).last, const Offset(0, 350));
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái: OPEN'), findsOneWidget);
    },
  );

  testWidgets(
    'OPEN history entry resumes checkout and updates history on return',
    (tester) async {
      visitStatus = 'OPEN';
      await open(tester, const VisitHistoryScreen());
      await tap(tester, 'Địa điểm kiểm thử');
      expect(find.byType(VisitScreen), findsOneWidget);
      await tap(tester, 'Check-out');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Trạng thái: VERIFIED'), findsOneWidget);
      expect(find.textContaining('tiếp tục Check-out'), findsNothing);
    },
  );

  testWidgets('Visit 401 removes nested screens and displays login', (
    tester,
  ) async {
    await open(tester, VisitScreen(placeId: visitJson()['placeId'] as String));
    mutation = (_) => apiResponse(null, status: 401);
    await tap(tester, 'Check-in');
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(VisitScreen), findsNothing);
    expect(storage.token, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated checkout taps send one request while pending', (
    tester,
  ) async {
    visitStatus = 'OPEN';
    await open(
      tester,
      VisitScreen(
        placeId: visitJson()['placeId'] as String,
        visitId: visitJson()['id'] as String,
      ),
    );
    final pending = Completer<ResponseBody>();
    mutation = (_) => pending.future;
    await tester.tap(find.text('Check-out'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Check-out'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      backend.requests.where((request) => request.method == 'PUT'),
      hasLength(1),
    );
    pending.complete(apiResponse(visitJson(status: 'VERIFIED')));
    await tester.pumpAndSettle();
    expect(find.text('Trạng thái: VERIFIED'), findsOneWidget);
  });
}
