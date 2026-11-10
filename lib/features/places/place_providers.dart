import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'place_model.dart';
import 'place_service.dart';

// Provider tìm kiếm địa điểm kết hợp keyword và category
final placesListProvider = FutureProvider.autoDispose
    .family<List<PlaceSummaryModel>, ({String keyword, String category})>((
      ref,
      query,
    ) async {
      final service = ref.watch(placeServiceProvider);
      return service.searchPlaces(
        keyword: query.keyword,
        category: query.category == 'ALL' ? null : query.category,
      );
    });

final placeDetailProvider = FutureProvider.autoDispose
    .family<PlaceDetailModel, String>((ref, placeId) async {
      final service = ref.watch(placeServiceProvider);
      return service.getPlaceDetail(placeId);
    });
