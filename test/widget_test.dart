import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/geometry.dart';
import 'package:grok_companion/features/home/home_page.dart';
import 'package:grok_companion/features/stage/grok_stage.dart';
import 'package:grok_companion/services/chat_controller.dart';
import 'package:grok_companion/services/expression_store.dart';
import 'package:grok_companion/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('主页骨架渲染：设置入口、表情舞台、输入栏', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    final raw = File('assets/geo/grok_geo.json').readAsStringSync();
    final stage = StageController(GrokGeometry.fromJsonString(raw));
    final tmp = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'grok_widget_${DateTime.now().millisecondsSinceEpoch}',
    );
    final chat = ChatController(
      stage: stage,
      settingsStore: SettingsStore(vault: InMemoryKeyVault()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          settingsStore: SettingsStore(vault: InMemoryKeyVault()),
          expressionStore: ExpressionStore(tmp),
          stage: stage,
          chat: chat,
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.text('和 Grok 聊点什么吧'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
