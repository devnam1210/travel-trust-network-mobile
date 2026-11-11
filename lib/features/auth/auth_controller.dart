import 'dart:async';

import '../../core/session_tokens.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_model.dart';
import 'auth_session.dart';
import '../../core/api_service.dart';
import 'auth_service.dart';
import 'token_storage.dart';
import '../profile/profile_service.dart';
import '../notifications/notification_service.dart';

// Re-export the same provider so existing features need no import changes.
export '../../core/api_service.dart' show apiServiceProvider;

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
  SessionTokens? _tokens;
  bool _endingSession = false;
  Future<void> _credentialWork = Future.value();

  Future<T> _credentials<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _credentialWork = _credentialWork.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<bool> _refreshAccessToken() async {
    final previous = _tokens;
    if (!ref.mounted || _endingSession || previous?.refreshToken == null) {
      return false;
    }
    final version = _api.sessionVersion;
    final next = await _auth.refresh(previous!.refreshToken!);
    return _credentials(() async {
      if (!ref.mounted || version != _api.sessionVersion) return false;
      await _storage.writeTokens(next);
      if (!ref.mounted || version != _api.sessionVersion) return false;
      _tokens = next;
      _api.rotateAccessToken(next.accessToken);
      return true;
    });
  }

  ApiService get _api => ref.read(apiServiceProvider);
  AuthService get _auth => ref.read(authServiceProvider);
  ProfileService get _profile => ref.read(profileServiceProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    final api = _api;
    api.onRefreshAccessToken = _refreshAccessToken;
    api.onVisitUnauthorized = () async {
      if (ref.mounted &&
          !_endingSession &&
          state.status == AuthStatus.authenticated) {
        await _expireSession();
      }
    };
    ref.onDispose(() {
      api.onVisitUnauthorized = null;
      api.onRefreshAccessToken = null;
    });
    scheduleMicrotask(() {
      if (ref.mounted) unawaited(restoreSession());
    });
    return const AuthState(status: AuthStatus.restoring);
  }

  Future<void> restoreSession() async {
    if (state.isBusy) return;
    state = const AuthState(status: AuthStatus.restoring, isBusy: true);
    try {
      final tokens = await _storage.readTokens();
      if (!ref.mounted) return;
      if (tokens == null) {
        _api.accessToken = null;
        state = const AuthState();
        return;
      }
      _tokens = tokens;
      _api.accessToken = tokens.accessToken;
      final user = await _profile.getProfile();
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

  Future<void> signInWithGoogle() => _authenticate(_auth.signInWithGoogle);

  Future<void> register(String email, String fullName, String password) =>
      _authenticate(
        () => _auth.register(
          email: email,
          fullName: fullName,
          password: password,
        ),
      );

  Future<void> _authenticate(Future<AuthSession?> Function() request) async {
    if (state.isBusy || state.status != AuthStatus.signedOut) return;
    state = const AuthState(isBusy: true);
    try {
      final session = await request();
      if (!ref.mounted) return;
      if (session == null) {
        state = const AuthState();
        return;
      }
      await _credentials(() => _storage.writeTokens(session.tokens));
      if (!ref.mounted) return;
      _tokens = session.tokens;
      _api.accessToken = session.accessToken;
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
    } catch (error) {
      if (ref.mounted) state = AuthState(error: _message(error));
    }
  }

  Future<void> refreshProfile() async {
    if (state.isBusy || state.status != AuthStatus.authenticated) return;
    final user = state.user;
    final token = _api.sessionVersion;
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
      isBusy: true,
    );
    try {
      final updated = await _profile.getProfile();
      if (ref.mounted && token == _api.sessionVersion) {
        state = AuthState(status: AuthStatus.authenticated, user: updated);
      }
    } catch (error) {
      if (!ref.mounted || token != _api.sessionVersion) return;
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

  Future<void> updateProfile({
    required String fullName,
    String? bio,
    String? avatarUrl,
  }) async {
    if (state.isBusy || state.status != AuthStatus.authenticated) return;
    final user = state.user;
    final token = _api.sessionVersion;
    state = AuthState(
      status: AuthStatus.authenticated,
      user: user,
      isBusy: true,
    );
    try {
      final updated = await _profile.updateProfile(
        fullName: fullName,
        bio: bio,
        avatarUrl: avatarUrl,
      );
      if (ref.mounted && token == _api.sessionVersion) {
        state = AuthState(status: AuthStatus.authenticated, user: updated);
      }
    } catch (error) {
      if (!ref.mounted || token != _api.sessionVersion) return;
      if (_invalidSession(error)) {
        await _expireSession();
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          error: _message(error),
        );
        rethrow;
      }
    }
  }

  Future<void> logout() async {
    if (state.isBusy) return;
    final previous = state;
    _endingSession = true;
    state = AuthState(
      status: previous.status,
      user: previous.user,
      isBusy: true,
    );
    try {
      // Finish any rotation already in flight before revoking the resulting family.
      await _api.waitForRefresh();
      if (!ref.mounted) return;
      final refresh = _tokens?.refreshToken;
      if (refresh != null) await _auth.logout(refresh);
      await ref.read(pushRegistrationProvider).detach();
      await _credentials(() => _storage.clear());
      if (!ref.mounted) return;
      _tokens = null;
      _api.accessToken = null;
      state = const AuthState();
    } catch (_) {
      if (ref.mounted) {
        state = AuthState(
          status: previous.status,
          user: previous.user,
          error: 'Không thể đăng xuất. Kiểm tra kết nối và thử lại.',
        );
      }
    } finally {
      _endingSession = false;
    }
  }

  bool _invalidSession(Object error) =>
      error is FormatException ||
      (error is ApiException &&
          (error.isUnauthorized || error.statusCode == 404));

  Future<void> _expireSession() async {
    state = const AuthState(status: AuthStatus.restoring, isBusy: true);
    _api.accessToken = null;
    try {
      // An expired request may itself be registering/removing a device. Avoid waiting on that same request.
      unawaited(ref.read(pushRegistrationProvider).detach());
      await _credentials(() => _storage.clear());
      _tokens = null;
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
