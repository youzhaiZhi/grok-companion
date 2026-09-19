import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'features/home/home_page.dart';
import 'services/expression_store.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore.init();
  final docs = await getApplicationDocumentsDirectory();
  runApp(
    GrokCompanionApp(
      settingsStore: settings,
      expressionStore: ExpressionStore(docs),
    ),
  );
}

class GrokCompanionApp extends StatelessWidget {
  const GrokCompanionApp({
    super.key,
    required this.settingsStore,
    required this.expressionStore,
  });

  final SettingsStore settingsStore;
  final ExpressionStore expressionStore;

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
      home: HomePage(
        settingsStore: settingsStore,
        expressionStore: expressionStore,
      ),
    );
  }
}
