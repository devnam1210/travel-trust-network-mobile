import '../models/auth_session.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  AuthService({required this.api});

  final ApiService api;
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

  Future<UserModel> getProfile() async =>
      UserModel.fromJson(await api.get('/users/me/profile'));
}
