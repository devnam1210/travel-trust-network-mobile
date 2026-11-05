import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travel_trust_network_mobile/controllers/auth_controller.dart';
import 'package:travel_trust_network_mobile/models/place_model.dart';
import 'package:travel_trust_network_mobile/models/visit_model.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/location_service.dart';
import 'package:travel_trust_network_mobile/services/visit_service.dart';
import 'package:travel_trust_network_mobile/views/visits/visit_screen.dart';

class ReadyAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

class TestLocationService extends LocationService {
  @override
  Future<Position> getCurrentPosition() async => Position(
    latitude: 21.03040,
    longitude: 105.53445,
    timestamp: DateTime.now(),
    accuracy: 18,
    hasAccuracy: true,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class RejectingVisitService extends VisitService {
  RejectingVisitService() : super(api: ApiService());

  int calls = 0;
  double? sentLatitude;
  double? sentAccuracy;

  @override
  Future<VisitModel> checkIn({
    required String placeId,
    required double userLat,
    required double userLng,
    required double? gpsAccuracy,
    required bool isMocked,
  }) async {
    calls++;
    sentLatitude = userLat;
    sentAccuracy = gpsAccuracy;
    throw const ApiException(
      'Vị trí của bạn vượt quá bán kính xác thực cho phép (200m).',
      code: 'GPS_OUT_OF_RADIUS',
      statusCode: 400,
    );
  }
}

void main() {
  const place = PlaceDetailModel(
    id: '22222222-2222-2222-2222-222222222207',
    name: 'Trọ T&H Hostel',
    category: 'HOSTEL',
    address: 'Test place',
    latitude: 21.02840,
    longitude: 105.53445,
    allowedRadiusM: 200,
  );
  late RejectingVisitService visits;

  setUp(() => visits = RejectingVisitService());
  tearDown(() => visits.api.close());

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(ReadyAuthController.new),
          locationServiceProvider.overrideWithValue(TestLocationService()),
          visitServiceProvider.overrideWithValue(visits),
          visitPlaceProvider.overrideWith((ref, id) async => place),
        ],
        child: MaterialApp(home: VisitScreen(placeId: place.id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'GPS preview shows target, device accuracy and distance without check-in',
    (tester) async {
      await openScreen(tester);
      await tester.tap(find.text('Kiểm tra GPS / Đo lại'));
      await tester.pumpAndSettle();

      expect(
        find.text('GPS điện thoại: 21.030400, 105.534450'),
        findsOneWidget,
      );
      expect(
        find.text('Tọa độ địa điểm: 21.028400, 105.534450'),
        findsOneWidget,
      );
      expect(find.text('Sai số ước tính: ±18.0 m'), findsOneWidget);
      expect(find.text('Khoảng cách ước tính: 222.6 m'), findsOneWidget);
      expect(visits.calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed check-in keeps the actual sent GPS visible for diagnosis',
    (tester) async {
      await openScreen(tester);
      await tester.ensureVisible(find.text('Check-in'));
      await tester.tap(find.text('Check-in'));
      await tester.pumpAndSettle();

      expect(visits.calls, 1);
      expect(visits.sentLatitude, 21.03040);
      expect(visits.sentAccuracy, 18);
      expect(
        find.text('GPS điện thoại: 21.030400, 105.534450'),
        findsOneWidget,
      );
      expect(
        find.text('Vị trí của bạn vượt quá bán kính xác thực cho phép (200m).'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
