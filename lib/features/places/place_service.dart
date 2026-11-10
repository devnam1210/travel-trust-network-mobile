import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'place_model.dart';
import '../../core/api_service.dart';

final placeServiceProvider = Provider<PlaceService>(
  (ref) => PlaceService(api: ref.watch(apiServiceProvider)),
);

class PlaceService {
  PlaceService({required this.api});

  final ApiService api;

  Future<List<PlaceSummaryModel>> searchPlaces({
    String? keyword,
    String? category,
  }) async {
    final queryParams = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      queryParams['keyword'] = keyword.trim();
    }
    if (category != null && category.trim().isNotEmpty && category != 'ALL') {
      queryParams['category'] = category.trim();
    }

    final uri = Uri(
      path: '/places',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    final data = await api.getList(uri.toString());
    return data
        .map((item) => PlaceSummaryModel.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<PlaceDetailModel> getPlaceDetail(String id) async {
    final data = await api.get('/places/${Uri.encodeComponent(id)}');
    return PlaceDetailModel.fromJson(data);
  }
}
