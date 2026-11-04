import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/models/review_model.dart';

void main() {
  group('ReviewModel Tests', () {
    test('fromJson parses review response correctly', () {
      final json = {
        'id': '33333333-3333-3333-3333-333333333301',
        'userId': '44444444-4444-4444-4444-444444444401',
        'fullName': 'Nguyễn Văn A',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'placeId': '11111111-1111-1111-1111-111111111101',
        'visitId': '55555555-5555-5555-5555-555555555501',
        'rating': 4,
        'comment': 'Không gian học tập rất tuyệt vời.',
        'postcardImageUrl': null,
        'is360Media': true,
        'isVerifiedReview': true,
        'createdAt': '2026-11-04T14:20:00',
      };

      final review = ReviewModel.fromJson(json);

      expect(review.id, '33333333-3333-3333-3333-333333333301');
      expect(review.userId, '44444444-4444-4444-4444-444444444401');
      expect(review.fullName, 'Nguyễn Văn A');
      expect(review.avatarUrl, 'https://example.com/avatar.jpg');
      expect(review.rating, 4);
      expect(review.comment, 'Không gian học tập rất tuyệt vời.');
      expect(review.postcardImageUrl, isNull);
      expect(review.is360Media, isTrue);
      expect(review.isVerifiedReview, isTrue);
      expect(review.createdAt, DateTime(2026, 11, 4, 14, 20));
    });
  });
}
