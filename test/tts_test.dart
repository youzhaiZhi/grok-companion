import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/services/settings_store.dart';
import 'package:grok_companion/services/tts_service.dart';

class _FakeEngine implements TtsEngine {
  _FakeEngine(this.result);

  final TtsResult result;
  final List<String> calls = [];
  bool stopped = false;

  @override
  Future<TtsResult> speak(String text, AppSettings settings) async {
    calls.add(text);
    return result;
  }

  @override
  Future<void> stop() async => stopped = true;
}

void main() {
  test('off 模式：不调用任何引擎', () async {
    final local = _FakeEngine(TtsResult.spokenLocal);
    final cloud = _FakeEngine(TtsResult.spokenCloud);
    final s = Speaker(local: local, cloud: cloud);
    final r = await s.speak('你好', AppSettings(ttsMode: 'off'));
    expect(r, TtsResult.failed);
    expect(local.calls, isEmpty);
    expect(cloud.calls, isEmpty);
  });

  test('local 模式：调用本地引擎', () async {
    final local = _FakeEngine(TtsResult.spokenLocal);
    final cloud = _FakeEngine(TtsResult.spokenCloud);
    final s = Speaker(local: local, cloud: cloud);
    final r = await s.speak('你好', AppSettings(ttsMode: 'local'));
    expect(r, TtsResult.spokenLocal);
    expect(local.calls.single, '你好');
    expect(cloud.calls, isEmpty);
  });

  test('cloud 成功：只调云端', () async {
    final local = _FakeEngine(TtsResult.spokenLocal);
    final cloud = _FakeEngine(TtsResult.spokenCloud);
    final s = Speaker(local: local, cloud: cloud);
    final r = await s.speak('你好', AppSettings(ttsMode: 'cloud'));
    expect(r, TtsResult.spokenCloud);
    expect(cloud.calls.single, '你好');
    expect(local.calls, isEmpty);
  });

  test('cloud 失败：自动回退本地', () async {
    final local = _FakeEngine(TtsResult.spokenLocal);
    final cloud = _FakeEngine(TtsResult.failed);
    final s = Speaker(local: local, cloud: cloud);
    final r = await s.speak('你好', AppSettings(ttsMode: 'cloud'));
    expect(r, TtsResult.spokenLocal);
    expect(cloud.calls, hasLength(1));
    expect(local.calls, hasLength(1));
  });

  test('stop：两个引擎都收到停止', () async {
    final local = _FakeEngine(TtsResult.spokenLocal);
    final cloud = _FakeEngine(TtsResult.spokenCloud);
    final s = Speaker(local: local, cloud: cloud);
    await s.stop();
    expect(local.stopped, true);
    expect(cloud.stopped, true);
  });

  test('空白文本不播放', () async {
    final local = _FakeEngine(TtsResult.spokenLocal);
    final cloud = _FakeEngine(TtsResult.spokenCloud);
    final s = Speaker(local: local, cloud: cloud);
    expect(await s.speak('   ', AppSettings(ttsMode: 'cloud')),
        TtsResult.failed);
    expect(cloud.calls, isEmpty);
  });
}
