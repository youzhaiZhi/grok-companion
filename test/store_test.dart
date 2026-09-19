import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/character.dart';
import 'package:grok_companion/services/expression_store.dart';
import 'package:grok_companion/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('设置写入→重新加载一致；Key 经独立 KeyVault 存储', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = InMemoryKeyVault();
    final store = SettingsStore(prefs: prefs, vault: vault);

    final s = AppSettings(
      baseUrl: 'https://api.example.com/v1',
      apiKey: 'sk-secret-123',
      model: 'grok-test',
      temperature: 0.42,
      ttsMode: 'cloud',
      ttsVoice: 'nova',
      ttsRate: 1.2,
      allowShapeColor: false,
      showDots: false,
      reduceMotion: true,
    );
    await store.save(s);

    final raw = prefs.getString('api_key');
    expect(raw, isNull, reason: 'Key 不得明文进入 SharedPreferences');
    expect(await vault.readKey(), 'sk-secret-123');

    final reloaded = await SettingsStore(prefs: prefs, vault: vault).load();
    expect(reloaded.baseUrl, s.baseUrl);
    expect(reloaded.apiKey, s.apiKey);
    expect(reloaded.model, s.model);
    expect(reloaded.temperature, closeTo(s.temperature, 1e-9));
    expect(reloaded.ttsMode, s.ttsMode);
    expect(reloaded.ttsVoice, s.ttsVoice);
    expect(reloaded.ttsRate, closeTo(s.ttsRate, 1e-9));
    expect(reloaded.allowShapeColor, false);
    expect(reloaded.showDots, false);
    expect(reloaded.reduceMotion, true);
  });

  test('自定义表情 CRUD 持久化（模拟重启：新建 store 同目录）', () async {
    final tmp = await Directory.systemTemp.createTemp('grok_store_test');
    addTearDown(() => tmp.delete(recursive: true));

    final exp = RegisteredExpression(
      id: 'shy_expect',
      cnName: '腼腆期待',
      desc: '测试用',
      base: 'shy',
      intensity: 0.72,
      holdMs: 2600,
      lid: 0.8,
      eyeBoost: 1.05,
      shape: 'cloud',
      color: 'violet',
    );

    await ExpressionStore(tmp).save(exp);
    final list = await ExpressionStore(tmp).loadAll();
    expect(list.length, 1);
    final back = list.single;
    expect(back.id, exp.id);
    expect(back.cnName, exp.cnName);
    expect(back.base, exp.base);
    expect(back.intensity, closeTo(exp.intensity, 1e-9));
    expect(back.holdMs, exp.holdMs);
    expect(back.lid, exp.lid);
    expect(back.eyeBoost, exp.eyeBoost);
    expect(back.shape, exp.shape);
    expect(back.color, exp.color);

    expect(await ExpressionStore(tmp).delete('shy_expect'), true);
    expect(await ExpressionStore(tmp).loadAll(), isEmpty);
    expect(await ExpressionStore(tmp).delete('shy_expect'), false);
  });

  test('损坏的表情文件被安全跳过，不抛异常', () async {
    final tmp = await Directory.systemTemp.createTemp('grok_badjson');
    addTearDown(() => tmp.delete(recursive: true));
    final dir = Directory('${tmp.path}${Platform.pathSeparator}expressions');
    await dir.create(recursive: true);
    await File('${dir.path}${Platform.pathSeparator}broken.json')
        .writeAsString('{not json');
    expect(await ExpressionStore(tmp).loadAll(), isEmpty);
  });

  test('lib/ 中无明文打印 API Key 的代码', () async {
    final lib = Directory('lib');
    final files = await lib
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.dart'))
        .cast<File>()
        .toList();
    final bad = <String>[];
    for (final f in files) {
      final lines = await f.readAsLines();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        final printsKey = RegExp(r'(debugPrint|print)\s*\(').hasMatch(l) &&
            (l.contains('apiKey') || l.contains('api_key'));
        if (printsKey) bad.add('${f.path}:${i + 1} $l');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
