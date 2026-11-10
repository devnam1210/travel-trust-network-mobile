import 'package:flutter_test/flutter_test.dart';
import 'package:travel_trust_network_mobile/core/api_service.dart';
import 'package:travel_trust_network_mobile/features/places/place_service.dart';

class FakeApiService extends ApiService {
  String? lastPath;
  Map<String, dynamic>? lastData;

  @override
  Future<List<dynamic>> getList(String path) async {
    lastPath = path;
    return [
      {
        'id': '11111111-1111-1111-1111-111111111101',
        'name': 'FPT University',
        'category': 'CAMPUS',
        'address': 'Hoa Lac',
        'imageUrl': null,
        'averageRating': 5.0,
        'verifiedReviewCount': 10,
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> get(String path) async {
    lastPath = path;
    return {
      'id': '11111111-1111-1111-1111-111111111101',
      'name': 'FPT University',
      'category': 'CAMPUS',
      'description': 'Tech campus',
      'address': 'Hoa Lac',
      'latitude': 21.0,
      'longitude': 105.0,
      'allowedRadiusM': 500.0,
      'averageRating': 5.0,
      'verifiedReviewCount': 10,
      'reviews': [],
    };
  }
}

void main() {
  group('PlaceService Tests', () {
    late FakeApiService fakeApi;
    late PlaceService service;

    setUp(() {
      fakeApi = FakeApiService();
      service = PlaceService(api: fakeApi);
    });

    test('searchPlaces builds correct query string with keyword and category',
        () async {
      final results = await service.searchPlaces(
        keyword: 'FPT',
        category: 'CAMPUS',
      );

      expect(results.length, 1);
      expect(fakeApi.lastPath, contains('/places?keyword=FPT&category=CAMPUS'));
    });

    test('searchPlaces ignores category ALL to fetch all categories', () async {
      await service.searchPlaces(
        keyword: 'Hanoi',
        category: 'ALL',
      );

      expect(fakeApi.lastPath, contains('/places?keyword=Hanoi'));
      expect(fakeApi.lastPath, isNot(contains('category=')));
    });

    test('getPlaceDetail encodes place id in path', () async {
      const placeId = '11111111-1111-1111-1111-111111111101';
      final detail = await service.getPlaceDetail(placeId);

      expect(detail.id, placeId);
      expect(fakeApi.lastPath, '/places/$placeId');
    });
  });
}
