class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.placeId,
    required this.visitId,
    required this.rating,
    required this.comment,
    required this.is360Media,
    required this.isVerifiedReview,
    required this.createdAt,
    this.avatarUrl,
    this.postcardImageUrl,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    fullName: json['fullName'] as String,
    placeId: json['placeId'] as String,
    visitId: json['visitId'] as String,
    rating: (json['rating'] as num).toInt(),
    comment: json['comment'] as String,
    is360Media: json['is360Media'] as bool? ?? false,
    isVerifiedReview: json['isVerifiedReview'] as bool? ?? true,
    createdAt: DateTime.parse(json['createdAt'] as String),
    avatarUrl: json['avatarUrl'] as String?,
    postcardImageUrl: json['postcardImageUrl'] as String?,
  );

  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String placeId;
  final String visitId;
  final int rating;
  final String comment;
  final String? postcardImageUrl;
  final bool is360Media;
  final bool isVerifiedReview;
  final DateTime createdAt;
}
