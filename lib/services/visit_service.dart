import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../models/visit_model.dart';
import 'api_service.dart';

final visitServiceProvider = Provider<VisitService>(
  (ref) => VisitService(api: ref.watch(apiServiceProvider)),
);

final visitHistoryProvider = FutureProvider.autoDispose<List<VisitModel>>((
  ref,
) {
  final userId = ref.watch(
    authControllerProvider.select((auth) => auth.user?.id),
  );
  if (userId == null) return [];
  return ref.watch(visitServiceProvider).getMyHistory();
});

class VisitService {
  VisitService({required this.api});

  final ApiService api;

  Future<VisitModel> checkIn({
    required String placeId,
    required double userLat,
    required double userLng,
    required double? gpsAccuracy,
    required bool isMocked,
  }) async => VisitModel.fromJson(
    await api.post('/visits/check-in', {
      'placeId': placeId,
      'userLat': userLat,
      'userLng': userLng,
      'gpsAccuracy': gpsAccuracy,
      'isMocked': isMocked,
    }),
  );

  Future<VisitModel> checkOut(String visitId) async => VisitModel.fromJson(
    await api.put('/visits/${Uri.encodeComponent(visitId)}/check-out'),
  );

  Future<List<VisitModel>> getMyHistory() async {
    final data = await api.getList('/visits/my-history');
    return data
        .map((item) => VisitModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
