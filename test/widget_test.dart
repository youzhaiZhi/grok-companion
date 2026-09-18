import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/features/home/home_page.dart';

void main() {
  testWidgets('主页骨架渲染：设置入口、表情舞台、输入栏', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.text('和 Grok 聊点什么吧'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
