class FriendUser {
  const FriendUser({
    required this.id,
    required this.fullName,
    this.username,
    this.avatarUrl,
    this.relationshipId,
    this.relationship = 'NONE',
  });

  factory FriendUser.fromJson(Map<String, dynamic> json) => FriendUser(
    id: json['id'] as String,
    fullName: json['fullName'] as String? ?? '',
    username: json['username'] as String?,
    avatarUrl: json['avatarUrl'] as String?,
    relationshipId: json['relationshipId'] as String?,
    relationship: json['relationship'] as String? ?? 'NONE',
  );

  final String id;
  final String fullName;
  final String? username;
  final String? avatarUrl;
  final String? relationshipId;
  final String relationship;
}
