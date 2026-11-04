class LocketSignal {
  const LocketSignal({
    required this.id,
    required this.senderName,
    this.placeName,
    required this.imageUrl,
    this.caption,
    required this.is360Image,
    this.sentAt,
  });

  factory LocketSignal.fromJson(Map<String, dynamic> json) => LocketSignal(
    id: json['id'] as String,
    senderName: json['senderName'] as String? ?? 'Ẩn danh',
    placeName: json['placeName'] as String?,
    imageUrl: json['imageUrl'] as String? ?? '',
    caption: json['caption'] as String?,
    is360Image: json['is360Image'] as bool? ?? false,
    sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
  );

  final String id;
  final String senderName;
  final String? placeName;
  final String imageUrl;
  final String? caption;
  final bool is360Image;
  final DateTime? sentAt;
}