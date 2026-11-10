import 'package:google_sign_in/google_sign_in.dart';

import '../../core/app_config.dart';
import 'auth_session.dart';
import '../../core/api_service.dart';

class AuthService {
  AuthService({required this.api});

  final ApiService api;
  static Future<void>? _googleInitialization;

  Future<AuthSession?> signInWithGoogle() async {
    if (AppConfig.googleServerClientId.trim().isEmpty) {
      throw const ApiException(
        'Chưa cấu hình GOOGLE_SERVER_CLIENT_ID (OAuth Web Client ID).',
      );
    }
    try {
      final google = GoogleSignIn.instance;
      _googleInitialization ??= google.initialize(
        serverClientId: AppConfig.googleServerClientId,
      );
      await _googleInitialization;
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw const ApiException(
          'Google không trả ID token. Kiểm tra OAuth Client ID.',
        );
      }
      return await loginWithGoogleToken(
        email: account.email,
        fullName: account.displayName?.trim().isNotEmpty == true
            ? account.displayName!.trim()
            : account.email,
        idToken: idToken,
        avatarUrl: account.photoUrl,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw ApiException(switch (error.code) {
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError => 'Cấu hình Google chưa đúng. Kiểm tra Web Client ID, package Android và SHA-1.',
        _ => 'Đăng nhập Google thất bại. Kiểm tra mạng và thử lại.',
      });
    }
  }

  Future<AuthSession> loginWithGoogleToken({
    required String email,
    required String fullName,
    required String idToken,
    String? avatarUrl,
  }) async {
    if (idToken.trim().isEmpty) {
      throw const ApiException('Google ID token không hợp lệ.');
    }
    try {
      return AuthSession.fromJson(
        await api.post('/auth/google', {
          'email': email,
          'fullName': fullName,
          'idToken': idToken,
          'avatarUrl': avatarUrl,
          'fcmToken': null,
        }),
      );
    } on ApiException catch (error) {
      if (error.message == 'Google login is not configured.') {
        throw const ApiException(
          'Backend chưa cấu hình GOOGLE_CLIENT_ID. Vui lòng cấu hình rồi thử lại.',
          statusCode: 401,
          code: 'UNAUTHORIZED',
        );
      }
      rethrow;
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async => AuthSession.fromJson(
    await api.post('/auth/login', {'email': email, 'password': password}),
  );

  Future<AuthSession> register({
    required String email,
    required String fullName,
    required String password,
  }) async => AuthSession.fromJson(
    await api.post('/auth/register', {
      'email': email,
      'fullName': fullName,
      'password': password,
    }),
  );
}
