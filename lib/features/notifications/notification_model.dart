class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.type,
    required this.title,
    required this.body,
    required this.targetId,
    this.createdAt,
    this.readAt,
  });

  final String id, recipientId, actorId, type, title, body, targetId;
  final DateTime? createdAt, readAt;
  bool get isMessage => type == 'MESSAGE';

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: (j['id'] ?? j['notificationId']).toString(),
    recipientId: j['recipientId'] as String,
    actorId: j['actorId'] as String,
    type: j['type'] as String,
    title: j['title'] as String? ?? 'Thông báo mới',
    body: j['body'] as String? ?? '',
    targetId: j['targetId'] as String,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    readAt: DateTime.tryParse(j['readAt'] as String? ?? ''),
  );
}
