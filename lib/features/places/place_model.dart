import '../reviews/review_model.dart';

class PlaceSummaryModel {
  const PlaceSummaryModel({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    this.imageUrl,
    this.averageRating = 0.0,
    this.verifiedReviewCount = 0,
  });

  factory PlaceSummaryModel.fromJson(Map<String, dynamic> json) =>
      PlaceSummaryModel(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        address: json['address'] as String,
        imageUrl: json['imageUrl'] as String?,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
        verifiedReviewCount:
            (json['verifiedReviewCount'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final String category;
  final String address;
  final String? imageUrl;
  final double averageRating;
  final int verifiedReviewCount;
}

class PlaceDetailModel {
  const PlaceDetailModel({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.allowedRadiusM,
    this.description,
    this.imageUrl,
    this.openingHours,
    this.averageRating = 0.0,
    this.verifiedReviewCount = 0,
    this.reviews = const [],
  });

  factory PlaceDetailModel.fromJson(Map<String, dynamic> json) {
    final rawReviews = json['reviews'] as List<dynamic>? ?? [];
    return PlaceDetailModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      allowedRadiusM: (json['allowedRadiusM'] as num?)?.toDouble() ?? 200.0,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      openingHours: json['openingHours'] as String?,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      verifiedReviewCount:
          (json['verifiedReviewCount'] as num?)?.toInt() ?? 0,
      reviews: rawReviews
          .map((item) => ReviewModel.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final String category;
  final String address;
  final String? description;
  final String? imageUrl;
  final String? openingHours;
  final double latitude;
  final double longitude;
  final double allowedRadiusM;
  final double averageRating;
  final int verifiedReviewCount;
  final List<ReviewModel> reviews;
}
