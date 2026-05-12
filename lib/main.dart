import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/splash_screen.dart';
import 'theme.dart';

void main() {
  runApp(const ProviderScope(child: ScrappApp()));
}

class ScrappApp extends StatelessWidget {
  const ScrappApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scrapp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
