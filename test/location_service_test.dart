import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/geolocator');
  final calls = <String>[];
  var enabled = true;
  var permission = 2;
  var requestedPermission = 2;

  setUp(() {
    calls.clear();
    enabled = true;
    permission = 2;
    requestedPermission = 2;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'isLocationServiceEnabled' => enabled,
            'checkPermission' => permission,
            'requestPermission' => requestedPermission,
            'getCurrentPosition' => {
              'latitude': 21.0,
              'longitude': 105.0,
              'accuracy': 8.5,
              'timestamp': 1793757600000,
              'is_mocked': true,
            },
            _ => null,
          };
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'gets current coordinates and preserves device accuracy/mock indicator',
    () async {
      final position = await LocationService().getCurrentPosition();
      expect(position.latitude, 21.0);
      expect(position.longitude, 105.0);
      expect(position.accuracy, 8.5);
      expect(position.isMocked, true);
      expect(calls, [
        'isLocationServiceEnabled',
        'checkPermission',
        'getCurrentPosition',
      ]);
    },
  );

  test('GPS disabled prevents coordinate access', () async {
    enabled = false;
    await expectLater(
      LocationService().getCurrentPosition(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'GPS_DISABLED'),
      ),
    );
    expect(calls, ['isLocationServiceEnabled']);
  });

  test('requests missing permission before getting position', () async {
    permission = 0;
    await LocationService().getCurrentPosition();
    expect(
      calls,
      containsAllInOrder([
        'checkPermission',
        'requestPermission',
        'getCurrentPosition',
      ]),
    );
  });

  test('denied permission prevents coordinate access', () async {
    permission = 0;
    requestedPermission = 0;
    await expectLater(
      LocationService().getCurrentPosition(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'LOCATION_DENIED'),
      ),
    );
    expect(calls, isNot(contains('getCurrentPosition')));
  });

  test('permanent denial does not repeatedly prompt for permission', () async {
    permission = 1;
    await expectLater(
      LocationService().getCurrentPosition(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'LOCATION_DENIED_FOREVER',
        ),
      ),
    );
    expect(calls, isNot(contains('requestPermission')));
  });
}
