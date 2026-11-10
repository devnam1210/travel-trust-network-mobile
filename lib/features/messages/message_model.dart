class PhotoQuote {
  const PhotoQuote({
    required this.signalId,
    required this.mediaId,
    required this.senderName,
    this.caption,
  });
  factory PhotoQuote.fromJson(Map<String, dynamic> json) => PhotoQuote(
    signalId: json['signalId'] as String,
    mediaId: json['mediaId'] as String,
    senderName: json['senderName'] as String? ?? '',
    caption: json['caption'] as String?,
  );
  final String signalId, mediaId, senderName;
  final String? caption;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.clientMessageId,
    required this.body,
    this.sentAt,
    this.quote,
  });
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] as num).toInt(),
    senderId: json['senderId'] as String,
    clientMessageId: json['clientMessageId'] as String,
    body: json['body'] as String,
    sentAt: DateTime.tryParse(json['sentAt'] as String? ?? ''),
    quote: json['quote'] is Map<String, dynamic>
        ? PhotoQuote.fromJson(json['quote'] as Map<String, dynamic>)
        : null,
  );
  final int id;
  final String senderId, clientMessageId, body;
  final DateTime? sentAt;
  final PhotoQuote? quote;
}

class Conversation {
  const Conversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.canSend,
    this.peerAvatarUrl,
    this.lastMessage,
    this.updatedAt,
    this.unreadCount = 0,
  });
  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    peerId: json['peerId'] as String,
    peerName: json['peerName'] as String? ?? '',
    canSend: json['canSend'] as bool? ?? false,
    peerAvatarUrl: json['peerAvatarUrl'] as String?,
    lastMessage: json['lastMessage'] as String?,
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  );
  final String id, peerId, peerName;
  final bool canSend;
  final String? peerAvatarUrl, lastMessage;
  final DateTime? updatedAt;
  final int unreadCount;
}
