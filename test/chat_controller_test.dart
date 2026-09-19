import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/geometry.dart';
import 'package:grok_companion/features/stage/grok_stage.dart';
import 'package:grok_companion/services/chat_controller.dart';
import 'package:grok_companion/services/llm_service.dart';
import 'package:grok_companion/services/settings_store.dart';
import 'package:grok_companion/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopEngine implements TtsEngine {
  @override
  Future<TtsResult> speak(String text, AppSettings settings) async =>
      TtsResult.failed;

  @override
  Future<void> stop() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final raw = File('assets/geo/grok_geo.json').readAsStringSync();
  final geo = GrokGeometry.fromJsonString(raw);

  ChatController build(Stream<String> stream) {
    SharedPreferences.setMockInitialValues({
      'base_url': 'https://api.test/v1',
      'model': 'grok-test',
    });
    final store = SettingsStore(vault: InMemoryKeyVault());
    return ChatController(
      stage: StageController(geo),
      settingsStore: store,
      speaker: Speaker(local: _NoopEngine(), cloud: _NoopEngine()),
      streamer: ({
        required baseUrl,
        required apiKey,
        required model,
        required messages,
        temperature = 0.7,
      }) =>
          stream,
    );
  }

  test('完整轮：listening→writing（标签剥离/情绪生效）→结束保持→idle', () {
    fakeAsync((clk) {
      final controller = StreamController<String>();
      Timer(Duration.zero, () => controller.add('你好[[happy]]世界'));
      Timer(const Duration(milliseconds: 20), controller.close);
      final c = build(controller.stream);

      final fut = c.send('在吗');
      clk.flushMicrotasks();
      expect(fut, completes);
      expect(c.phase, ChatPhase.listening);
      expect(c.stage.character.state, 'listening');
      expect(c.entries.single.text, '在吗');

      clk.elapse(const Duration(milliseconds: 1));
      expect(c.phase, ChatPhase.writing);
      final ai = c.entries.last;
      expect(ai.role, 'assistant');
      expect(ai.text, '你好世界');
      expect(c.stage.character.state, 'happy');

      clk.elapse(const Duration(milliseconds: 25));
      expect(c.phase, ChatPhase.idle);
      expect(c.stage.character.state, 'happy');

      clk.elapse(const Duration(milliseconds: 2800));
      expect(c.stage.character.state, 'idle');
    });
  });

  test('3.5s 无首字：进入 thinking', () {
    fakeAsync((clk) {
      final c = build(StreamController<String>().stream);
      final fut = c.send('在吗');
      clk.flushMicrotasks();
      expect(fut, completes);
      expect(c.phase, ChatPhase.listening);

      clk.elapse(const Duration(milliseconds: 3499));
      expect(c.phase, ChatPhase.listening);
      clk.elapse(const Duration(milliseconds: 2));
      expect(c.phase, ChatPhase.thinking);
      expect(c.stage.character.state, 'thinking');
    });
  });

  test('401 错误：错误文案 + 安抚表情，随后回 idle', () {
    fakeAsync((clk) {
      final c = build(Stream<String>.fromFuture(
        Future(() => throw LlmException(LlmErrorKind.auth, '')),
      ));
      final fut = c.send('在吗');
      clk.flushMicrotasks();
      expect(fut, completes);

      clk.elapse(const Duration(milliseconds: 1));
      expect(c.phase, ChatPhase.error);
      expect(c.errorText, 'API Key 无效或没有权限');
      expect(c.stage.character.state, 'sad');

      clk.elapse(const Duration(milliseconds: 2800));
      expect(c.phase, ChatPhase.idle);
      expect(c.errorText, isNull);
      expect(c.stage.character.state, 'idle');
    });
  });

  test('stop：中断进行中的会话并立即回 idle', () {
    fakeAsync((clk) {
      final delayed = Stream<String>.fromFuture(
        Future.delayed(const Duration(seconds: 1), () => '慢'),
      );
      final c = build(delayed);
      final fut = c.send('在吗');
      clk.flushMicrotasks();
      expect(fut, completes);
      expect(c.phase, ChatPhase.listening);
      c.stop();
      expect(c.phase, ChatPhase.idle);
      expect(c.stage.character.state, 'idle');
      clk.elapse(const Duration(seconds: 2));
      expect(c.phase, ChatPhase.idle);
    });
  });
}
