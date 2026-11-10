class VisitModel {
  const VisitModel({
    required this.id,
    required this.placeId,
    required this.placeName,
    required this.status,
    required this.checkInTime,
    this.placeImageUrl,
    this.checkOutTime,
    this.distanceMeters,
    this.rejectionReason,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) => VisitModel(
    id: json['id'] as String,
    placeId: json['placeId'] as String,
    placeName: json['placeName'] as String,
    status: json['status'] as String,
    placeImageUrl: json['placeImageUrl'] as String?,
    checkInTime: DateTime.parse(json['checkInTime'] as String),
    checkOutTime: json['checkOutTime'] == null
        ? null
        : DateTime.parse(json['checkOutTime'] as String),
    distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    rejectionReason: json['rejectionReason'] as String?,
  );

  final String id;
  final String placeId;
  final String placeName;
  final String status;
  final String? placeImageUrl;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final double? distanceMeters;
  final String? rejectionReason;

  bool get isOpen => status == 'OPEN';
}
