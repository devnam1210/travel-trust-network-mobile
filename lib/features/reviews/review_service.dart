import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'review_model.dart';
import '../../core/api_service.dart';

final reviewServiceProvider = Provider<ReviewService>(
  (ref) => ReviewService(api: ref.watch(apiServiceProvider)),
);

class ReviewService {
  ReviewService({required this.api});

  final ApiService api;

  Future<ReviewModel> createReview({
    required String visitId,
    required String placeId,
    required int rating,
    required String comment,
    String? postcardImageUrl,
    bool is360Media = false,
  }) async {
    final response = await api.post('/reviews', {
      'visitId': visitId,
      'placeId': placeId,
      'rating': rating,
      'comment': comment,
      'postcardImageUrl': postcardImageUrl,
      'is360Media': is360Media,
    });
    return ReviewModel.fromJson(response);
  }
}
