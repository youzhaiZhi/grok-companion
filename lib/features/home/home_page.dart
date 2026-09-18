import 'dart:ui';

import 'package:flutter/material.dart';

import '../settings/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatBubbleData> _messages = [];
  bool _ttsOn = false;
  bool _composing = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatBubbleData(text, true));
      _composing = true;
    });
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              ttsOn: _ttsOn,
              onTts: () => setState(() => _ttsOn = !_ttsOn),
              onSettings: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              ),
            ),
            const _Stage(),
            Expanded(child: _ChatArea(messages: _messages, scroll: _scroll)),
            _InputBar(
              controller: _input,
              composing: _composing,
              onSend: _send,
              onStop: () => setState(() => _composing = false),
              hintColor: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatBubbleData {
  ChatBubbleData(this.text, this.isUser);

  final String text;
  final bool isUser;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.ttsOn,
    required this.onTts,
    required this.onSettings,
  });

  final bool ttsOn;
  final VoidCallback onTts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: '设置',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
          const Spacer(),
          IconButton(
            tooltip: ttsOn ? '关闭语音' : '开启语音',
            onPressed: onTts,
            icon: Icon(ttsOn ? Icons.volume_up_outlined : Icons.volume_off_outlined),
          ),
        ],
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 300,
      child: Center(
        child: Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sentiment_satisfied_outlined,
            size: 88,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _ChatArea extends StatelessWidget {
  const _ChatArea({required this.messages, required this.scroll});

  final List<ChatBubbleData> messages;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (messages.isEmpty) {
      return Center(
        child: Text(
          '和 Grok 聊点什么吧',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, i) => _Bubble(data: messages[i]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.data});

  final ChatBubbleData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: data.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: data.isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(data.text, style: const TextStyle(fontSize: 14)),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.composing,
    required this.onSend,
    required this.onStop,
    required this.hintColor,
  });

  final TextEditingController controller;
  final bool composing;
  final VoidCallback onSend;
  final VoidCallback onStop;
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
                    onTap: composing ? onStop : onSend,
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: scheme.onSurface,
                      child: Icon(
                        composing ? Icons.stop_rounded : Icons.arrow_upward_rounded,
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
