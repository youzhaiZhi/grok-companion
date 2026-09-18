import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionLabel('AI 服务'),
          _Tile(
            icon: Icons.cloud_outlined,
            title: '模型与接口',
            subtitle: 'Base URL · API Key · 模型',
            onTap: () => _open(context, '模型与接口'),
          ),
          const _SectionLabel('语音'),
          _Tile(
            icon: Icons.record_voice_over_outlined,
            title: '语音 TTS',
            subtitle: '云端 / 本地 / 关闭 · 音色与语速',
            onTap: () => _open(context, '语音 TTS'),
          ),
          const _SectionLabel('表情'),
          _Tile(
            icon: Icons.emoji_emotions_outlined,
            title: '表情库',
            subtitle: '23 个预设 · 预览与自定义',
            onTap: () => _open(context, '表情库'),
          ),
          const _SectionLabel('显示'),
          _Tile(
            icon: Icons.shuffle_outlined,
            title: 'AI 形态与颜色',
            subtitle: '允许 AI 切换预设形态与颜色',
            onTap: () => _open(context, 'AI 形态与颜色'),
          ),
          _Tile(
            icon: Icons.bubble_chart_outlined,
            title: '思考点缀',
            subtitle: '思考时显示小圆点',
            onTap: () => _open(context, '思考点缀'),
          ),
          _Tile(
            icon: Icons.animation_outlined,
            title: '减少动态效果',
            subtitle: '跟随系统',
            onTap: () => _open(context, '减少动态效果'),
          ),
          const _SectionLabel('其他'),
          _Tile(
            icon: Icons.info_outline,
            title: '关于',
            subtitle: 'Grok 助手 1.0.0',
            onTap: () => _open(context, '关于'),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _PlaceholderPage(title: title)),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '「$title」即将上线',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
