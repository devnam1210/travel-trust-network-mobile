class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    required this.trustScore,
    required this.verifiedVisitCount,
    required this.trustScoreLogs,
    this.createdAt,
    this.username,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    bio: json['bio'] as String?,
    trustScore: (json['trustScore'] as num?)?.toInt() ?? 0,
    verifiedVisitCount: (json['verifiedVisitCount'] as num?)?.toInt() ?? 0,
    trustScoreLogs: (json['trustScoreLogs'] as List<dynamic>? ?? [])
        .map((entry) => TrustScoreLog.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    username: json['username'] as String?,
  );

  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final int trustScore;
  final int verifiedVisitCount;
  final List<TrustScoreLog> trustScoreLogs;
  final DateTime? createdAt;
  final String? username;
}

class TrustScoreLog {
  const TrustScoreLog({
    required this.id,
    required this.delta,
    required this.newScore,
    required this.reason,
    this.createdAt,
  });

  factory TrustScoreLog.fromJson(Map<String, dynamic> json) => TrustScoreLog(
    id: json['id'] as String,
    delta: (json['delta'] as num).toInt(),
    newScore: (json['newScore'] as num).toInt(),
    reason: json['reason'] as String,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );

  final String id;
  final int delta;
  final int newScore;
  final String reason;
  final DateTime? createdAt;
}
