import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_service.dart';
import '../auth/user_model.dart';

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(api: ref.watch(apiServiceProvider)),
);

class ProfileService {
  ProfileService({required this.api});

  final ApiService api;

  Future<UserModel> getProfile() async =>
      UserModel.fromJson(await api.get('/users/me/profile'));

  Future<UserModel> updateProfile({
    required String fullName,
    String? bio,
    String? avatarUrl,
  }) async => UserModel.fromJson(
    await api.put('/users/me/profile', {
      'fullName': fullName,
      'bio': bio,
      'avatarUrl': avatarUrl,
    }),
  );
}
