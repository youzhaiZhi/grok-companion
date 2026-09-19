import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/character.dart';
import '../engine/idle_director.dart';
import '../features/stage/grok_stage.dart';
import 'expression_protocol.dart';
import 'llm_service.dart';
import 'settings_store.dart';
import 'tts_service.dart';

enum ChatPhase { idle, listening, thinking, writing, error }

class ChatEntry {
  ChatEntry(this.role, this.text);

  final String role;
  String text;
}

typedef ChatStreamer = Stream<String> Function({
  required String baseUrl,
  required String apiKey,
  required String model,
  required List<ChatMsg> messages,
  double temperature,
});

class ChatController extends ChangeNotifier {
  ChatController({
    required this.stage,
    required this.settingsStore,
    ChatStreamer? streamer,
    Speaker? speaker,
    IdleDirector? director,
    this.loadCustoms,
  })  : _streamer = streamer ??
            (({
              required baseUrl,
              required apiKey,
              required model,
              required messages,
              temperature = 0.7,
            }) =>
                LlmService().streamChat(
                  baseUrl: baseUrl,
                  apiKey: apiKey,
                  model: model,
                  messages: messages,
                  temperature: temperature,
                )),
        _speaker = speaker ?? Speaker(),
        _director = director ?? IdleDirector();

  final StageController stage;
  final SettingsStore settingsStore;
  final Future<List<RegisteredExpression>> Function()? loadCustoms;

  final ChatStreamer _streamer;
  final Speaker _speaker;
  final IdleDirector _director;

  final List<ChatEntry> entries = [];
  ChatPhase phase = ChatPhase.idle;
  String? errorText;
  List<RegisteredExpression> customs = [];

  StreamSubscription<String>? _sub;
  Timer? _thinkingTimer;
  Timer? _idleReturn;
  String? _lastMood;
  String _assistant = '';
  double _frameMs = 0;
  AppSettings _cached = AppSettings();

  Future<void> prime() async {
    _cached = await settingsStore.load();
    stage.character
      ..reduceMotion = _cached.reduceMotion
      ..showDots = _cached.showDots;
    if (loadCustoms != null) customs = await loadCustoms!();
  }

  /// 每帧由舞台 ticker 调用，驱动待机导演。
  void direct(double frameMs) {
    _frameMs = frameMs;
    final out = _director.update(
      frameMs,
      enabled: phase == ChatPhase.idle,
      reduceMotion: _cached.reduceMotion,
    );
    if (out != null) {
      stage.setExpression(out);
      stage.character.autoTricks = out == 'idle';
    }
  }

  void markUserInput() {
    _director.notifyUserEvent(_frameMs);
    _idleReturn?.cancel();
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    if (phase == ChatPhase.listening || phase == ChatPhase.writing) return;
    _cancelFlow();

    _cached = await settingsStore.load();
    if (loadCustoms != null) customs = await loadCustoms!();
    final settings = _cached;

    entries.add(ChatEntry('user', text));
    phase = ChatPhase.listening;
    stage.character.autoTricks = true;
    stage.setExpression('listening');
    _director.notifyUserEvent(_frameMs);
    notifyListeners();

    final history = <ChatMsg>[
      ChatMsg('system', buildExpressionCatalog(customs: customs)),
      for (final e in entries) ChatMsg(e.role, e.text),
    ];

    final aiEntry = ChatEntry('assistant', '');
    _assistant = '';
    _lastMood = null;
    final proto = ExpressionProtocol(customIds: customs.map((c) => c.id));

    _thinkingTimer = Timer(const Duration(milliseconds: 3500), () {
      if (phase == ChatPhase.listening) {
        phase = ChatPhase.thinking;
        stage.setExpression('thinking');
        notifyListeners();
      }
    });

    final stream = _streamer(
      baseUrl: settings.baseUrl,
      apiKey: settings.apiKey,
      model: settings.model,
      messages: history,
      temperature: settings.temperature,
    );

    _sub = stream.listen(
      (delta) {
        if (_assistant.isEmpty) {
          _thinkingTimer?.cancel();
          entries.add(aiEntry);
          phase = ChatPhase.writing;
          stage.setExpression('writing');
        }
        final out = proto.feed(delta);
        _assistant += out.text;
        aiEntry.text = _assistant;
        for (final c in out.commands) {
          _applyMood(c, settings);
        }
        notifyListeners();
      },
      onError: (Object e) {
        _thinkingTimer?.cancel();
        errorText = e is LlmException ? e.cnText : '出了点问题，请稍后再试';
        phase = ChatPhase.error;
        stage.setExpression('sad');
        notifyListeners();
        _scheduleReturnToIdle();
      },
      onDone: () {
        _thinkingTimer?.cancel();
        phase = ChatPhase.idle;
        notifyListeners();
        if (_assistant.trim().isNotEmpty) _speaker.speak(_assistant, settings);
        stage.setExpression(_lastMood ?? 'idle');
        _scheduleReturnToIdle();
      },
      cancelOnError: true,
    );
  }

  void _applyMood(ExpressionCommand c, AppSettings s) {
    final ok = stage.setExpression(
      c.id,
      intensity: c.intensity,
      holdMs: c.holdMs,
      shape: s.allowShapeColor ? c.shape : null,
      color: s.allowShapeColor ? c.color : null,
    );
    _lastMood = ok ? c.id : _lastMood;
  }

  void _scheduleReturnToIdle() {
    _idleReturn?.cancel();
    _idleReturn = Timer(const Duration(milliseconds: 2800), () {
      if (phase == ChatPhase.idle || phase == ChatPhase.error) {
        phase = ChatPhase.idle;
        errorText = null;
        stage.setExpression('idle');
        notifyListeners();
      }
    });
  }

  void stop() {
    _cancelFlow();
    phase = ChatPhase.idle;
    stage.character.autoTricks = true;
    stage.setExpression('idle');
    notifyListeners();
  }

  void _cancelFlow() {
    _sub?.cancel();
    _sub = null;
    _thinkingTimer?.cancel();
    _idleReturn?.cancel();
    _speaker.stop();
  }

  @override
  void dispose() {
    _cancelFlow();
    super.dispose();
  }
}
