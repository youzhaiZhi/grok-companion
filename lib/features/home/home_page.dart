import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/geometry.dart';
import '../../services/chat_controller.dart';
import '../../services/expression_store.dart';
import '../../services/settings_store.dart';
import '../settings/settings_page.dart';
import '../stage/grok_stage.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.settingsStore,
    required this.expressionStore,
    this.stage,
    this.chat,
  });

  final SettingsStore settingsStore;
  final ExpressionStore expressionStore;

  /// 可选的预装配控制器（提供后跳过异步引导；主要用于测试）。
  final StageController? stage;
  final ChatController? chat;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  StageController? _stage;
  ChatController? _chat;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.stage != null && widget.chat != null) {
      _stage = widget.stage;
      _chat = widget.chat;
      _ready = true;
    } else {
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    final raw = await rootBundle.loadString('assets/geo/grok_geo.json');
    final stage = StageController(GrokGeometry.fromJsonString(raw));
    final chat = ChatController(
      stage: stage,
      settingsStore: widget.settingsStore,
      loadCustoms: () async {
        final list = await widget.expressionStore.loadAll();
        for (final c in list) {
          stage.character.registerCustom(c);
        }
        return list;
      },
    );
    await chat.prime();
    if (!mounted) return;
    setState(() {
      _stage = stage;
      _chat = chat;
      _ready = true;
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _chat?.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _chat?.send(text);
    _input.clear();
  }

  Future<void> _cycleTts() async {
    final s = await widget.settingsStore.load();
    final next = switch (s.ttsMode) {
      'off' => 'local',
      'local' => 'cloud',
      _ => 'off',
    };
    await widget.settingsStore.save(s.copyWith(ttsMode: next));
    setState(() {});
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent - _scroll.offset < 120) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stage = _stage;
    final chat = _chat;
    if (!_ready || stage == null || chat == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onTts: _cycleTts),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SizedBox(
                height: 244,
                child: GrokStage(controller: stage, onFrame: chat.direct),
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: chat,
                builder: (context, _) {
                  _autoScroll();
                  return _ChatArea(chat: chat, scroll: _scroll);
                },
              ),
            ),
            ListenableBuilder(
              listenable: chat,
              builder: (context, _) => _InputBar(
                controller: _input,
                busy: chat.phase == ChatPhase.listening ||
                    chat.phase == ChatPhase.writing,
                onSend: _send,
                onStop: chat.stop,
                onTyping: chat.markUserInput,
                hintColor: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onTts});

  final Future<void> Function() onTts;

  @override
  Widget build(BuildContext context) {
    final home = context.findAncestorWidgetOfExactType<HomePage>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          IconButton(
            tooltip: '设置',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SettingsPage(settingsStore: home.settingsStore),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          const Spacer(),
          FutureBuilder<AppSettings>(
            future: home.settingsStore.load(),
            builder: (context, snap) {
              final mode = snap.data?.ttsMode ?? 'off';
              final icon = switch (mode) {
                'cloud' => Icons.cloud_outlined,
                'local' => Icons.volume_up_outlined,
                _ => Icons.volume_off_outlined,
              };
              return IconButton(
                tooltip: '语音：关闭 / 本地 / 云端',
                onPressed: onTts,
                icon: Icon(icon),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChatArea extends StatelessWidget {
  const _ChatArea({required this.chat, required this.scroll});

  final ChatController chat;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (chat.errorText != null)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.errorContainer.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 16, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(chat.errorText!,
                      style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onErrorContainer)),
                ),
              ],
            ),
          ),
        Expanded(
          child: chat.entries.isEmpty
              ? Center(
                  child: Text(
                    '和 Grok 聊点什么吧',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  controller: scroll,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: chat.entries.length,
                  itemBuilder: (context, i) =>
                      _Bubble(entry: chat.entries[i]),
                ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry});

  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = entry.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          entry.text.isEmpty ? '…' : entry.text,
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.onStop,
    required this.onTyping,
    required this.hintColor,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final VoidCallback onTyping;
  final Color hintColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool light = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: light
                  ? Colors.white.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: light
                    ? Colors.black.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onChanged: (_) => onTyping(),
                    onSubmitted: (_) => onSend(),
                    decoration: InputDecoration(
                      hintText: '输入消息…',
                      hintStyle: TextStyle(color: hintColor, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5),
                  child: GestureDetector(
                    onTap: busy ? onStop : onSend,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: scheme.onSurface,
                      child: Icon(
                        busy
                            ? Icons.stop_rounded
                            : Icons.arrow_upward_rounded,
                        size: 21,
                        color: scheme.surface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
