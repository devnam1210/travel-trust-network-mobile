import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_screen.dart';

class RegisterScreen extends ConsumerWidget {
  const RegisterScreen({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !ref.read(authControllerProvider).isBusy) onLogin();
    },
    child: AuthScreen(isRegistration: true, onSwitchMode: onLogin),
  );
}
