import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/auth_controller.dart';
import '../profile_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _register = false;

  void _switchMode(bool register) {
    ref.read(authControllerProvider.notifier).clearError();
    setState(() => _register = register);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) _register = false;
      if (previous?.status == AuthStatus.authenticated &&
          next.status != AuthStatus.authenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        });
      }
    });
    switch (auth.status) {
      case AuthStatus.restoring:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Đang kiểm tra phiên đăng nhập…'),
              ],
            ),
          ),
        );
      case AuthStatus.restoreFailed:
        final controller = ref.read(authControllerProvider.notifier);
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        'Chưa thể khôi phục phiên',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        auth.error ?? 'Vui lòng thử lại.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.isBusy
                            ? null
                            : controller.restoreSession,
                        child: const Text('Thử lại'),
                      ),
                      TextButton(
                        onPressed: auth.isBusy ? null : controller.logout,
                        child: const Text('Đăng xuất phiên đã lưu'),
                      ),
                      if (auth.isBusy) const LinearProgressIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      case AuthStatus.authenticated:
        return ProfileScreen(user: auth.user!);
      case AuthStatus.signedOut:
        return _register
            ? RegisterScreen(onLogin: () => _switchMode(false))
            : LoginScreen(onRegister: () => _switchMode(true));
    }
  }
}
