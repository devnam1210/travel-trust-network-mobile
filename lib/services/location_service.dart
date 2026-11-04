import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'api_service.dart';

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

class LocationService {
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException(
        'GPS đang tắt. Vui lòng bật dịch vụ vị trí.',
        code: 'GPS_DISABLED',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
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
}
