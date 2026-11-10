import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/features/places/place_model.dart';

void main() {
  group('PlaceSummaryModel Tests', () {
    test('fromJson parses summary json correctly with valid fields', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111101',
        'name': 'Đại học FPT Hà Nội',
        'category': 'CAMPUS',
        'address': 'Khu CNC Hòa Lạc, Thạch Thất, Hà Nội',
        'imageUrl': '/uploads/fpt.png',
        'averageRating': 4.8,
        'verifiedReviewCount': 12,
      };

      final place = PlaceSummaryModel.fromJson(json);

      expect(place.id, '11111111-1111-1111-1111-111111111101');
      expect(place.name, 'Đại học FPT Hà Nội');
      expect(place.category, 'CAMPUS');
      expect(place.address, 'Khu CNC Hòa Lạc, Thạch Thất, Hà Nội');
      expect(place.imageUrl, '/uploads/fpt.png');
      expect(place.averageRating, 4.8);
      expect(place.verifiedReviewCount, 12);
    });

    test('fromJson handles null optional fields gracefully with defaults', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111102',
        'name': 'Hồ Gươm',
        'category': 'HERITAGE',
        'address': 'Hoàn Kiếm, Hà Nội',
        'imageUrl': null,
        'averageRating': null,
        'verifiedReviewCount': null,
      };

      final place = PlaceSummaryModel.fromJson(json);

      expect(place.id, '11111111-1111-1111-1111-111111111102');
      expect(place.imageUrl, isNull);
      expect(place.averageRating, 0.0);
      expect(place.verifiedReviewCount, 0);
    });
  });

  group('PlaceDetailModel Tests', () {
    test('fromJson parses detail json with nested reviews and GPS rules', () {
      final json = {
        'id': '11111111-1111-1111-1111-111111111101',
        'name': 'Đại học FPT Hà Nội',
        'category': 'CAMPUS',
        'description': 'Khuôn viên công nghệ hiện đại bậc nhất.',
        'address': 'Khu CNC Hòa Lạc',
        'imageUrl': '/uploads/campus.jpg',
        'openingHours': '07:30 - 17:30',
        'latitude': 21.0124,
        'longitude': 105.5253,
        'allowedRadiusM': 500.0,
        'averageRating': 4.9,
        'verifiedReviewCount': 1,
        'reviews': [
          {
            'id': '33333333-3333-3333-3333-333333333301',
            'userId': '44444444-4444-4444-4444-444444444401',
            'fullName': 'Phạm Hoàng Nam',
            'placeId': '11111111-1111-1111-1111-111111111101',
            'visitId': '55555555-5555-5555-5555-555555555501',
            'rating': 5,
            'comment': 'Trường rất đẹp và rộng rãi!',
            'postcardImageUrl': '/uploads/card.png',
            'is360Media': false,
            'isVerifiedReview': true,
            'createdAt': '2026-11-04T10:30:00',
          }
        ],
      };

      final detail = PlaceDetailModel.fromJson(json);

      expect(detail.id, '11111111-1111-1111-1111-111111111101');
      expect(detail.latitude, 21.0124);
      expect(detail.longitude, 105.5253);
      expect(detail.allowedRadiusM, 500.0);
      expect(detail.openingHours, '07:30 - 17:30');
      expect(detail.reviews.length, 1);
      expect(detail.reviews.first.fullName, 'Phạm Hoàng Nam');
      expect(detail.reviews.first.rating, 5);
      expect(detail.reviews.first.isVerifiedReview, isTrue);
    });
  });
}
