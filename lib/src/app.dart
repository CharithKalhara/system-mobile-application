import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/session_controller.dart';
import 'features/home/dashboard_screen.dart';
import 'features/auth/login_screen.dart';

class NaduMobileApp extends ConsumerWidget {
  const NaduMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return MaterialApp(
      title: 'Nadu Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF173D52),
          surface: const Color(0xFFF7F8F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F7),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8DFE2)),
          ),
        ),
      ),
      home: switch (session.status) {
        SessionStatus.loading => const _LoadingScreen(),
        SessionStatus.signedOut => const LoginScreen(),
        SessionStatus.signedIn => const DashboardScreen(),
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
