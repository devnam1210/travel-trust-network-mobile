import 'package:flutter/material.dart';

import 'widgets/auth_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) =>
      AuthScreen(isRegistration: false, onSwitchMode: onRegister);
}
