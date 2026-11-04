import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/visit_service.dart';

import 'support/auth_fakes.dart';
import 'support/visit_fakes.dart';

void main() {
  late FakeBackend backend;
  late ApiService api;
  late VisitService service;

  setUp(() {
    backend = FakeBackend();
    api = ApiService(dio: Dio()..httpClientAdapter = backend)
      ..accessToken = 'jwt';
    service = VisitService(api: api);
  });
  tearDown(() => api.close());

  Future<void> checkIn() async {
    await service.checkIn(
      placeId: visitJson()['placeId'] as String,
      userLat: 21.0124,
      userLng: 105.5253,
      gpsAccuracy: 8.5,
      isMocked: true,
    );
  }

  test(
    'check-in sends actual GPS including the device mock flag and backend JWT',
    () async {
      backend.respond = (_) => apiResponse(visitJson());
      await checkIn();
      final request = backend.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/visits/check-in');
      expect(request.headers['Authorization'], 'Bearer jwt');
      expect(request.data, {
        'placeId': visitJson()['placeId'],
        'userLat': 21.0124,
        'userLng': 105.5253,
        'gpsAccuracy': 8.5,
        'isMocked': true,
      });
    },
  );

  test(
    'check-out is a bodyless PUT and status/time come from backend',
    () async {
      backend.respond = (_) => apiResponse(visitJson(status: 'VERIFIED'));
      final visit = await service.checkOut(visitJson()['id'] as String);
      expect(backend.requests.single.method, 'PUT');
      expect(backend.requests.single.path, '/visits/${visit.id}/check-out');
      expect(backend.requests.single.data, isNull);
      expect(visit.status, 'VERIFIED');
      expect(visit.checkOutTime, DateTime(2026, 11, 4, 10));
    },
  );

  test('history parses an array and does not send userId', () async {
    backend.respond = (_) =>
        apiResponse([visitJson(), visitJson(status: 'REJECTED')]);
    final visits = await service.getMyHistory();
    expect(visits, hasLength(2));
    expect(visits.first.isOpen, true);
    expect(visits.first.distanceMeters, 12.5);
    expect(visits.last.status, 'REJECTED');
    expect(backend.requests.single.path, '/visits/my-history');
    expect(backend.requests.single.queryParameters, isEmpty);
  });

  test(
    'empty history is valid; an object instead of an array is rejected',
    () async {
      backend.respond = (_) => apiResponse([]);
      expect(await service.getMyHistory(), isEmpty);
      backend.respond = (_) => apiResponse({});
      await expectLater(service.getMyHistory(), throwsA(isA<ApiException>()));
    },
  );

  for (final code in [
    'GPS_OUT_OF_RADIUS',
    'MOCK_LOCATION_DETECTED',
    'SINGLE_OPEN_VISIT',
    'ALREADY_CHECKED_OUT',
    'INVALID_CHECKOUT_TIME',
    'RESOURCE_NOT_FOUND',
    'FORBIDDEN',
  ]) {
    test('preserves backend business error $code', () async {
      backend.respond = (_) => apiResponse(
        null,
        status: code == 'FORBIDDEN' ? 403 : 400,
        code: code,
        message: 'Lỗi từ backend',
      );
      await expectLater(
        code.contains('GPS') ||
                code.contains('MOCK') ||
                code == 'SINGLE_OPEN_VISIT'
            ? checkIn()
            : service.checkOut('visit-id'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', code)),
      );
      expect(api.accessToken, 'jwt');
    });
  }

  test(
    'timeout marks result uncertain and never automatically repeats mutation',
    () async {
      backend.respond = (options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
      await expectLater(
        service.checkOut('visit-id'),
        throwsA(
          isA<ApiException>().having((e) => e.isUncertain, 'uncertain', true),
        ),
      );
      expect(backend.requests, hasLength(1));
      expect(api.accessToken, 'jwt');
    },
  );
}
