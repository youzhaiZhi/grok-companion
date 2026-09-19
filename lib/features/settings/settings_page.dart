import 'package:flutter/material.dart';

import '../../engine/tables.dart';
import '../../services/settings_store.dart';
import '../library/library_page.dart';
import 'ai_config_page.dart';
import 'tts_config_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppSettings _s = AppSettings();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.settingsStore.load().then((v) => setState(() {
          _s = v;
          _loaded = true;
        }));
  }

  Future<void> _toggle(void Function() change) async {
    setState(change);
    await widget.settingsStore.save(_s);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionLabel('AI 服务'),
          _Tile(
            icon: Icons.cloud_outlined,
            title: '模型与接口',
            subtitle: _s.apiReady
                ? '${_s.baseUrl} · ${_s.model}'
                : '未配置（点此设置）',
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiConfigPage(
                    settingsStore: widget.settingsStore,
                  ),
                ),
              );
              _s = await widget.settingsStore.load();
              setState(() {});
            },
          ),
          const _SectionLabel('语音'),
          _Tile(
            icon: Icons.record_voice_over_outlined,
            title: '语音 TTS',
            subtitle: switch (_s.ttsMode) {
              'cloud' => '云端 · ${_s.ttsVoice}',
              'local' => '本地 · 语速 ${_s.ttsRate}',
              _ => '关闭',
            },
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TtsConfigPage(
                    settingsStore: widget.settingsStore,
                  ),
                ),
              );
              _s = await widget.settingsStore.load();
              setState(() {});
            },
          ),
          const _SectionLabel('表情'),
          _Tile(
            icon: Icons.emoji_emotions_outlined,
            title: '表情库',
            subtitle: '23 个预设 · 预览与自定义',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LibraryPage(
                  settingsStore: widget.settingsStore,
                ),
              ),
            ),
          ),
          const _SectionLabel('显示'),
          SwitchListTile(
            secondary: const Icon(Icons.shuffle_outlined),
            title: const Text('允许 AI 切换形态与颜色'),
            value: _s.allowShapeColor,
            onChanged: (v) => _toggle(() => _s.allowShapeColor = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bubble_chart_outlined),
            title: const Text('思考点缀小圆点'),
            value: _s.showDots,
            onChanged: (v) => _toggle(() => _s.showDots = v),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.animation_outlined),
            title: const Text('减少动态效果'),
            subtitle: const Text('关闭跳跃与旋转，动作更轻柔'),
            value: _s.reduceMotion,
            onChanged: (v) => _toggle(() => _s.reduceMotion = v),
          ),
          const _SectionLabel('其他'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('关于'),
            subtitle: Text('Grok 助手 · 23 预设 · ${Tables.paletteIds.length} 色'),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'Grok 助手',
              applicationVersion: '1.0.0',
              children: const [Text('本地优先的表情 AI 助手，数据均存储在本机。')],
            ),
          ),
        ],
      ),
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
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
