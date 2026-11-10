import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_gate.dart';
import 'features/notifications/notification_host.dart';
import 'shared/motion/app_motion.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF126B5E));
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appMessengerKey,
      builder: (_, child) => NotificationHost(child: child!),
      title: 'Travel Trust Network',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            ...const PageTransitionsTheme().builders,
            TargetPlatform.android: const AppPageTransitionsBuilder(),
            TargetPlatform.windows: const AppPageTransitionsBuilder(),
            TargetPlatform.linux: const AppPageTransitionsBuilder(),
          },
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F3),
          centerTitle: false,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            animationDuration: AppMotion.press,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            animationDuration: AppMotion.press,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}
