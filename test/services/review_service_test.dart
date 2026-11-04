import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/services/api_service.dart';
import 'package:travel_trust_network_mobile/services/review_service.dart';

class FakeReviewApiService extends ApiService {
  String? lastPath;
  Map<String, dynamic>? lastData;

  @override
  Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> data) async {
    lastPath = path;
    lastData = data;
    return {
      'id': '33333333-3333-3333-3333-333333333301',
      'userId': '44444444-4444-4444-4444-444444444401',
      'fullName': 'Phạm Hoàng Nam',
      'placeId': data['placeId'],
      'visitId': data['visitId'],
      'rating': data['rating'],
      'comment': data['comment'],
      'postcardImageUrl': data['postcardImageUrl'],
      'is360Media': data['is360Media'] ?? false,
      'isVerifiedReview': true,
      'createdAt': '2026-11-04T12:00:00',
    };
  }
}

void main() {
  group('ReviewService Tests', () {
    late FakeReviewApiService fakeApi;
    late ReviewService service;

    setUp(() {
      fakeApi = FakeReviewApiService();
      service = ReviewService(api: fakeApi);
    });

    test('createReview sends correct payload to /reviews', () async {
      final review = await service.createReview(
        visitId: 'visit-123',
        placeId: 'place-456',
        rating: 5,
        comment: 'Tuyệt vời',
        postcardImageUrl: '/uploads/postcard.png',
        is360Media: true,
      );

      expect(fakeApi.lastPath, '/reviews');
      expect(fakeApi.lastData?['visitId'], 'visit-123');
      expect(fakeApi.lastData?['placeId'], 'place-456');
      expect(fakeApi.lastData?['rating'], 5);
      expect(fakeApi.lastData?['comment'], 'Tuyệt vời');
      expect(fakeApi.lastData?['postcardImageUrl'], '/uploads/postcard.png');
      expect(fakeApi.lastData?['is360Media'], isTrue);

      expect(review.rating, 5);
      expect(review.comment, 'Tuyệt vời');
      expect(review.isVerifiedReview, isTrue);
    });
  });
}
