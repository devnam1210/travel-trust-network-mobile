import 'user_model.dart';

class AuthSession {
  const AuthSession({required this.accessToken, required this.user});

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['accessToken'] as String;
    if (token.trim().isEmpty) {
      throw const FormatException('Missing access token');
    }
    return AuthSession(
      accessToken: token,
      user: UserModel.fromJson(json['userProfile'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final UserModel user;
}
