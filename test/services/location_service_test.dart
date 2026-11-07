import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/location_service.dart';

class TestLocationPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationAccuracyStatus accuracyStatus = LocationAccuracyStatus.precise;
  Stream<Position> positions = const Stream.empty();
  bool requestedPermission = false;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestedPermission = true;
    return LocationPermission.whileInUse;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async => accuracyStatus;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      positions;
}

final _now = DateTime.utc(2026, 11, 5, 4);

Position sample({
  double accuracy = 10,
  bool hasAccuracy = true,
  DateTime? timestamp,
  bool mocked = false,
  double latitude = 21.02840,
}) => Position(
  longitude: 105.53445,
  latitude: latitude,
  timestamp: timestamp ?? _now,
  accuracy: accuracy,
  hasAccuracy: hasAccuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
  isMocked: mocked,
);

void main() {
  late TestLocationPlatform platform;
  late LocationService service;

  setUp(() {
    platform = TestLocationPlatform();
    service = LocationService(
      platform: platform,
      now: () => _now,
      acquisitionTimeout: const Duration(milliseconds: 20),
    );
  });

  test('GPS disabled is reported before requesting a position', () async {
    platform.enabled = false;
    await expectLater(
      service.getCurrentPosition(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'GPS_DISABLED'),
      ),
    );
  });

  test(
    'approximate permission asks the user to enable precise location',
    () async {
      platform.accuracyStatus = LocationAccuracyStatus.reduced;
      await expectLater(
        service.getCurrentPosition(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'LOCATION_REDUCED_ACCURACY',
          ),
        ),
      );
    },
  );

  test('permission is requested when initially denied', () async {
    platform.permission = LocationPermission.denied;
    platform.positions = Stream.value(sample());
    await service.getCurrentPosition();
    expect(platform.requestedPermission, isTrue);
  });

  test(
    'ignores stale and invalid readings then waits for an accurate fix',
    () async {
      final good = sample(accuracy: 12);
      platform.positions = Stream.fromIterable([
        sample(timestamp: _now.subtract(const Duration(minutes: 2))),
        sample(latitude: double.nan),
        sample(accuracy: 900),
        good,
      ]);
      expect(await service.getCurrentPosition(), same(good));
    },
  );

  test(
    'returns the best reading and cancels the stream at the deadline',
    () async {
      var cancelled = false;
      final stream = StreamController<Position>(
        onCancel: () => cancelled = true,
      );
      platform.positions = stream.stream;
      final best = sample(accuracy: 80);
      stream.add(sample(accuracy: 900));
      stream.add(best);
      stream.add(sample(accuracy: 200));
      expect(await service.getCurrentPosition(), same(best));
      expect(cancelled, isTrue);
      await stream.close();
    },
  );

  test('a missing accuracy value of zero cannot beat a measured fix', () async {
    final measured = sample(accuracy: 80);
    platform.positions = Stream.fromIterable([
      sample(accuracy: 0, hasAccuracy: false),
      measured,
      sample(accuracy: 0, hasAccuracy: false),
    ]);
    expect(await service.getCurrentPosition(), same(measured));
  });

  test(
    'no recent position produces a retry message and releases stream',
    () async {
      var cancelled = false;
      final stream = StreamController<Position>(
        onCancel: () => cancelled = true,
      );
      platform.positions = stream.stream;
      stream.add(sample(timestamp: _now.subtract(const Duration(minutes: 2))));
      await expectLater(
        service.getCurrentPosition(),
        throwsA(isA<ApiException>()),
      );
      expect(cancelled, isTrue);
      await stream.close();
    },
  );

  test('does not remove the mocked flag used by backend validation', () async {
    platform.positions = Stream.value(sample(mocked: true));
    expect((await service.getCurrentPosition()).isMocked, isTrue);
  });

  test('falls back to a recent fix when the better sample ages out', () async {
    var clock = _now;
    service = LocationService(
      platform: platform,
      now: () => clock,
      acquisitionTimeout: const Duration(seconds: 1),
    );
    final recent = sample(accuracy: 200);
    final stream = StreamController<Position>(sync: true);
    platform.positions = stream.stream;
    final pending = service.getCurrentPosition();
    await Future<void>.delayed(Duration.zero);
    stream.add(
      sample(
        accuracy: 80,
        timestamp: _now.subtract(const Duration(seconds: 29)),
      ),
    );
    stream.add(recent);
    clock = _now.add(const Duration(seconds: 2));
    await stream.close();
    expect(await pending, same(recent));
  });

  test('location service disabled during acquisition is translated', () async {
    platform.positions = Stream.error(const LocationServiceDisabledException());
    await expectLater(
      service.getCurrentPosition(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'GPS_DISABLED'),
      ),
    );
  });
}
