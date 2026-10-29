import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../models/auth_session.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  final api = ApiService();
  ref.onDispose(api.close);
  return api;
});

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => const SecureTokenStorage(),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(api: ref.watch(apiServiceProvider)),
);

enum AuthStatus { restoring, signedOut, authenticated, restoreFailed }

class AuthState {
  const AuthState({
    this.status = AuthStatus.signedOut,
    this.user,
    this.isBusy = false,
    this.error,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool isBusy;
  final String? error;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  ApiService get _api => ref.read(apiServiceProvider);
  AuthService get _auth => ref.read(authServiceProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(restoreSession());
    });
    return const AuthState(status: AuthStatus.restoring);
  }

  Future<void> restoreSession() async {
    if (state.isBusy) return;
    state = const AuthState(status: AuthStatus.restoring, isBusy: true);
    try {
      final token = await _storage.read();
      if (!ref.mounted) return;
      if (token == null || token.trim().isEmpty) {
        _api.accessToken = null;
        state = const AuthState();
        return;
      }
      _api.accessToken = token;
      final user = await _auth.getProfile();
      if (ref.mounted) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } catch (error) {
      if (!ref.mounted) return;
      if (_invalidSession(error)) {
        await _expireSession();
      } else {
        // Keep the persisted token on connectivity/server errors for retry.
        _api.accessToken = null;
        state = AuthState(
          status: AuthStatus.restoreFailed,
          error: _message(error),
        );
      }
    }
  }

  Future<void> login(String email, String password) =>
      _authenticate(() => _auth.login(email: email, password: password));

  Future<void> register(String email, String fullName, String password) =>
      _authenticate(
        () => _auth.register(
          email: email,
          fullName: fullName,
          password: password,
        ),
      );

  Future<void> _authenticate(Future<AuthSession> Function() request) async {
    if (state.isBusy || state.status != AuthStatus.signedOut) return;
    state = const AuthState(isBusy: true);
    try {
      final session = await request();
      if (!ref.mounted) return;
      await _storage.write(session.accessToken);
      if (!ref.mounted) return;
      _api.accessToken = session.accessToken;
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
    } catch (error) {
      if (ref.mounted) state = AuthState(error: _message(error));
    }
  }

  Future<void> refreshProfile() async {
    if (state.isBusy || state.status != AuthStatus.authenticated) return;
    final user = state.user;
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
      isBusy: true,
    );
    try {
      final updated = await _auth.getProfile();
      if (ref.mounted) {
        state = AuthState(status: AuthStatus.authenticated, user: updated);
      }
    } catch (error) {
      if (!ref.mounted) return;
      if (_invalidSession(error)) {
        await _expireSession();
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          error: _message(error),
        );
      }
    }
  }

  Future<void> logout() async {
    if (state.isBusy) return;
    final previous = state;
    state = AuthState(
      status: previous.status,
      user: previous.user,
      isBusy: true,
    );
    try {
      await _storage.clear();
      if (!ref.mounted) return;
      _api.accessToken = null;
      if (ref.mounted) state = const AuthState();
    } catch (_) {
      if (ref.mounted) {
        state = AuthState(
          status: previous.status,
          user: previous.user,
          error: 'Không thể xóa phiên đã lưu. Vui lòng thử đăng xuất lại.',
        );
      }
    }
  }

  bool _invalidSession(Object error) =>
      error is ApiException &&
      (error.isUnauthorized || error.statusCode == 404);

  Future<void> _expireSession() async {
    _api.accessToken = null;
    try {
      await _storage.clear();
      if (!ref.mounted) return;
      if (ref.mounted) {
        state = const AuthState(
          error: 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        );
      }
    } catch (_) {
      if (ref.mounted) {
        state = const AuthState(
          status: AuthStatus.restoreFailed,
          error: 'Không thể xóa phiên hết hạn. Vui lòng thử lại.',
        );
      }
    }
  }

  void clearError() {
    if (state.error == null) return;
    state = AuthState(
      status: state.status,
      user: state.user,
      isBusy: state.isBusy,
    );
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Không thể hoàn tất xác thực. Vui lòng thử lại.';
}
