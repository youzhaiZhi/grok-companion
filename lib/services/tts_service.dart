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
  bool _configured = false;
  String? _resolvedLang;
  String? _lastError;

  String? get lastError => _lastError;

  /// 按可用性挑选语言：优先大陆/台湾中文，再退任何中文，最后用系统默认。
  Future<String?> _resolveLanguage() async {
    const candidates = ['zh-CN', 'zh-TW', 'zh-HK', 'zh'];
    for (final lang in candidates) {
      try {
        final ok = await _tts.isLanguageAvailable(lang);
        if (ok == true || (ok is int && ok == 1)) return lang;
      } catch (_) {}
    }
    try {
      final langs = await _tts.getLanguages;
      if (langs is List) {
        for (final l in langs) {
          if (l.toString().toLowerCase().startsWith('zh')) {
            return l.toString();
          }
        }
      }
    } catch (_) {}
    // 无中文引擎：返回 null，交给上层提示，而不是静默失败。
    return null;
  }

  Future<void> _configure() async {
    if (_configured) return;
    await _tts.awaitSpeakCompletion(true);
    _resolvedLang = await _resolveLanguage();
    if (_resolvedLang != null) {
      await _tts.setLanguage(_resolvedLang!);
    }
    _configured = true;
  }

  /// 用户语义语速（0.5–2）映射到 flutter_tts 的 0–1 值域。
  double _mapRate(double semantic) {
    final v = semantic.clamp(0.5, 2).toDouble();
    final mapped = 0.25 + (v - 0.5) * 0.5;
    return mapped.clamp(0.0, 1.0).toDouble();
  }

  @override
  Future<TtsResult> speak(String text, AppSettings settings) async {
    _lastError = null;
    try {
      await _tts.stop();
      await _configure();
      if (_resolvedLang == null) {
        _lastError = '本机没有可用的中文语音引擎，请安装后重试或使用云端 TTS';
        return TtsResult.failed;
      }
      await _tts.setSpeechRate(_mapRate(settings.ttsRate));
      final r = await _tts.speak(text);
      // Android 成功返回 1；iOS/macOS 返回 1；0 表示失败。
      if (r == 0) {
        _lastError = '语音引擎未能开始播放';
        return TtsResult.failed;
      }
      return TtsResult.spokenLocal;
    } catch (e) {
      _lastError = '本地 TTS 出错：$e';
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
  String? lastError;

  Future<TtsResult> speak(String text, AppSettings settings) async {
    lastError = null;
    if (text.trim().isEmpty) return TtsResult.failed;
    switch (settings.ttsMode) {
      case 'cloud':
        final r = await _cloud.speak(text, settings);
        if (r == TtsResult.spokenCloud) return r;
        final fb = await _local.speak(text, settings);
        if (fb == TtsResult.spokenLocal) {
          lastError = '云端 TTS 不可用，已用本地语音播放';
          return TtsResult.spokenLocal;
        }
        lastError = _local is LocalTtsEngine
            ? _local.lastError
            : '云端与本地 TTS 均不可用';
        return TtsResult.failed;
      case 'local':
        final r = await _local.speak(text, settings);
        if (r != TtsResult.spokenLocal && _local is LocalTtsEngine) {
          lastError = _local.lastError;
        }
        return r;
      default:
        return TtsResult.failed;
    }
  }

  Future<void> stop() async {
    await _local.stop();
    await _cloud.stop();
  }
}
