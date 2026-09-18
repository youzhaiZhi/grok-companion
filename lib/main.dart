import 'package:flutter/material.dart';

import 'features/home/home_page.dart';

void main() {
  runApp(const GrokCompanionApp());
}

class GrokCompanionApp extends StatelessWidget {
  const GrokCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5A5A5A);
    return MaterialApp(
      title: 'Grok 助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F2EC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101012),
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
