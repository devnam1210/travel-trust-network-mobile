import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/api_service.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

class LocationService {
  LocationService({
    GeolocatorPlatform? platform,
    this.acquisitionTimeout = const Duration(seconds: 20),
    DateTime Function()? now,
  }) : _platform = platform ?? GeolocatorPlatform.instance,
       _now = now ?? DateTime.now;

  final GeolocatorPlatform _platform;
  final DateTime Function() _now;
  final Duration acquisitionTimeout;

  Future<Position> getCurrentPosition() async {
    if (!await _platform.isLocationServiceEnabled()) {
      throw const ApiException(
        'GPS đang tắt. Vui lòng bật dịch vụ vị trí.',
        code: 'GPS_DISABLED',
      );
    }
    var permission = await _platform.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _platform.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Quyền vị trí bị từ chối vĩnh viễn. Hãy cấp quyền trong cài đặt ứng dụng.',
        code: 'LOCATION_DENIED_FOREVER',
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const ApiException(
        'Cần quyền vị trí để Check-in.',
        code: 'LOCATION_DENIED',
      );
    }
    try {
      if (await _platform.getLocationAccuracy() ==
          LocationAccuracyStatus.reduced) {
        throw const ApiException(
          'Ứng dụng chỉ được cấp vị trí gần đúng. Hãy bật Vị trí chính xác trong cài đặt quyền vị trí rồi thử lại.',
          code: 'LOCATION_REDUCED_ACCURACY',
        );
      }
      return await _acquirePosition();
    } on TimeoutException {
      throw const ApiException(
        'Chưa lấy được tọa độ GPS. Hãy ra nơi thoáng và thử lại.',
      );
    } on LocationServiceDisabledException {
      throw const ApiException(
        'GPS đang tắt. Vui lòng bật dịch vụ vị trí.',
        code: 'GPS_DISABLED',
      );
    } on PermissionDeniedException {
      throw const ApiException(
        'Quyền vị trí đã bị thu hồi. Vui lòng thử cấp quyền lại.',
      );
    }
  }

  Future<Position> _acquirePosition() async {
    final result = Completer<Position>();
    final samples = <Position>[];
    StreamSubscription<Position>? subscription;

    void finish() {
      if (result.isCompleted) return;
      Position? position;
      for (final candidate in samples) {
        if (!_isRecentValidPosition(candidate)) continue;
        if (position == null ||
            (_hasAccuracy(candidate) &&
                (!_hasAccuracy(position) ||
                    candidate.accuracy < position.accuracy))) {
          position = candidate;
        }
      }
      if (position == null) {
        result.completeError(TimeoutException('No recent GPS position.'));
      } else {
        result.complete(position);
      }
    }

    final timer = Timer(acquisitionTimeout, finish);
    try {
      subscription = _platform
          .getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 0,
            ),
          )
          .listen(
            (position) {
              if (result.isCompleted || !_isRecentValidPosition(position)) {
                return;
              }
              samples.removeWhere((sample) => !_isRecentValidPosition(sample));
              samples.add(position);
              if (_hasAccuracy(position) && position.accuracy <= 50) finish();
            },
            onError: (Object error, StackTrace stack) {
              if (!result.isCompleted) result.completeError(error, stack);
            },
            onDone: finish,
          );
      return await result.future;
    } finally {
      timer.cancel();
      await subscription?.cancel();
    }
  }

  bool _hasAccuracy(Position position) =>
      position.hasAccuracy &&
      position.accuracy.isFinite &&
      position.accuracy >= 0;

  bool _isRecentValidPosition(Position position) {
    final age = _now().difference(position.timestamp);
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude.abs() <= 90 &&
        position.longitude.abs() <= 180 &&
        age <= const Duration(seconds: 30) &&
        age >= const Duration(seconds: -5) &&
        (!position.hasAccuracy || _hasAccuracy(position));
  }
}
