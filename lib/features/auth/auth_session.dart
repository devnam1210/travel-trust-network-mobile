import 'user_model.dart';
import '../../core/session_tokens.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final tokens = SessionTokens.fromJson(json);
    final token = tokens.accessToken;
    if (token.trim().isEmpty) {
      throw const FormatException('Missing access token');
    }
    return AuthSession(
      accessToken: token,
      refreshToken: tokens.refreshToken,
      user: UserModel.fromJson(json['userProfile'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String? refreshToken;
  SessionTokens get tokens =>
      SessionTokens(accessToken: accessToken, refreshToken: refreshToken);
  final UserModel user;
}
