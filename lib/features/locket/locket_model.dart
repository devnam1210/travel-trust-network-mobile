class LocketReaction {
  const LocketReaction({
    required this.userId,
    required this.userName,
    required this.emoji,
  });
  factory LocketReaction.fromJson(Map<String, dynamic> json) => LocketReaction(
    userId: json['userId'] as String,
    userName: json['userName'] as String? ?? '',
    emoji: json['emoji'] as String,
  );
  final String userId;
  final String userName;
  final String emoji;
}

class LocketSignal {
  const LocketSignal({
    required this.id,
    required this.senderName,
    this.senderId,
    this.senderAvatarUrl,
    this.placeName,
    this.mediaId,
    required this.imageUrl,
    this.caption,
    required this.is360Image,
    this.sentAt,
    this.recipientIds = const [],
    this.reactions = const [],
  });

  factory LocketSignal.fromJson(Map<String, dynamic> json) => LocketSignal(
    id: json['id'] as String,
    senderId: json['senderId'] as String?,
    senderName: json['senderName'] as String? ?? 'Ẩn danh',
    senderAvatarUrl: json['senderAvatarUrl'] as String?,
    placeName: json['placeName'] as String?,
    mediaId: json['mediaId'] as String?,
    imageUrl: json['imageUrl'] as String? ?? '',
    caption: json['caption'] as String?,
    is360Image: json['is360Image'] as bool? ?? false,
    sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
    recipientIds: (json['recipientIds'] as List<dynamic>? ?? []).cast<String>(),
    reactions: (json['reactions'] as List<dynamic>? ?? [])
        .map((e) => LocketReaction.fromJson(e as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String id;
  final String? senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String? placeName;
  final String? mediaId;

  /// Kept for API compatibility; private images are loaded exclusively by mediaId.
  final String imageUrl;
  final String? caption;
  final bool is360Image;
  final DateTime? sentAt;
  final List<String> recipientIds;
  final List<LocketReaction> reactions;
}
