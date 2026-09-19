import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'llm_service.dart';
import 'settings_store.dart';

enum TtsResult { spokenCloud, spokenLocal, failed }

abstract class TtsEngine {
  Future<TtsResult> speak(String text, AppSettings settings);
  Future<void> stop();
}

/// 本地离线 TTS。
class LocalTtsEngine implements TtsEngine {
  LocalTtsEngine([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;

  Future<void> _configure(double rate) async {
    if (_ready) return;
    await _tts.setLanguage('zh-CN');
    _ready = true;
  }

  @override
  Future<TtsResult> speak(String text, AppSettings settings) async {
    try {
      await _tts.stop();
      await _configure(settings.ttsRate);
      await _tts.setSpeechRate(settings.ttsRate.clamp(0.5, 2).toDouble());
      await _tts.speak(text);
      return TtsResult.spokenLocal;
    } catch (_) {
      return TtsResult.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// 云端 TTS：/audio/speech → 临时 MP3 → just_audio。
class CloudTtsEngine implements TtsEngine {
  CloudTtsEngine({
    LlmService? llm,
    AudioPlayer? player,
    Future<Directory> Function()? tempDir,
  })  : _llm = llm ?? LlmService(),
        _player = player ?? AudioPlayer(),
        _tempDir = tempDir ?? getTemporaryDirectory;

  final LlmService _llm;
  final AudioPlayer _player;
  final Future<Directory> Function() _tempDir;

  @override
  Future<TtsResult> speak(String text, AppSettings settings) async {
    try {
      final bytes = await _llm.cloudTtsBytes(
        baseUrl: settings.baseUrl,
        apiKey: settings.apiKey,
        voice: settings.ttsVoice,
        input: text,
      );
      final dir = await _tempDir();
      final f = File('${dir.path}${Platform.pathSeparator}tts_cloud.mp3');
      await f.writeAsBytes(bytes, flush: true);
      await _player.stop();
      await _player.setFilePath(f.path);
      _player.play();
      await _player.playerStateStream
          .firstWhere((s) => s.processingState == ProcessingState.completed);
      return TtsResult.spokenCloud;
    } catch (_) {
      return TtsResult.failed;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }
}

/// 统一入口：按模式选择引擎；云端失败回退本地。
class Speaker {
  Speaker({TtsEngine? local, TtsEngine? cloud})
      : _local = local ?? LocalTtsEngine(),
        _cloud = cloud ?? CloudTtsEngine();

  final TtsEngine _local;
  final TtsEngine _cloud;

  Future<TtsResult> speak(String text, AppSettings settings) async {
    if (text.trim().isEmpty) return TtsResult.failed;
    switch (settings.ttsMode) {
      case 'cloud':
        final r = await _cloud.speak(text, settings);
        if (r == TtsResult.spokenCloud) return r;
        final fb = await _local.speak(text, settings);
        return fb == TtsResult.spokenLocal
            ? TtsResult.spokenLocal
            : TtsResult.failed;
      case 'local':
        return _local.speak(text, settings);
      default:
        return TtsResult.failed;
    }
  }

  Future<void> stop() async {
    await _local.stop();
    await _cloud.stop();
  }
}
