import 'package:flutter/material.dart';

import '../../services/settings_store.dart';
import '../../services/tts_service.dart';

const List<String> _voices = [
  'alloy',
  'echo',
  'fable',
  'onyx',
  'nova',
  'shimmer',
];

class TtsConfigPage extends StatefulWidget {
  const TtsConfigPage({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<TtsConfigPage> createState() => _TtsConfigPageState();
}

class _TtsConfigPageState extends State<TtsConfigPage> {
  AppSettings _s = AppSettings();
  bool _loaded = false;
  bool _trying = false;
  final Speaker _speaker = Speaker();

  @override
  void initState() {
    super.initState();
    widget.settingsStore.load().then((v) => setState(() {
          _s = v;
          _loaded = true;
        }));
  }

  Future<void> _apply(void Function() change) async {
    setState(change);
    await widget.settingsStore.save(_s);
  }

  Future<void> _preview() async {
    setState(() => _trying = true);
    final r = await _speaker.speak('你好，我是 Grok。', _s);
    if (mounted) {
      final text = switch (r) {
        TtsResult.spokenCloud => '云端语音播放中',
        TtsResult.spokenLocal =>
          _speaker.lastError ?? '本地语音播放中',
        TtsResult.failed =>
          _speaker.lastError ?? '播放失败，请检查配置或网络',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text)),
      );
      setState(() => _trying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('语音 TTS')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'off', icon: Icon(Icons.volume_off_outlined)),
              ButtonSegment(value: 'local', icon: Icon(Icons.smartphone)),
              ButtonSegment(
                  value: 'cloud', icon: Icon(Icons.cloud_outlined)),
            ],
            selected: {_s.ttsMode},
            onSelectionChanged: (v) => _apply(() => _s.ttsMode = v.first),
          ),
          const SizedBox(height: 24),
          Text('云端音色',
              style: Theme.of(context).textTheme.titleSmall),
          DropdownButton<String>(
            isExpanded: true,
            value: _voices.contains(_s.ttsVoice) ? _s.ttsVoice : _voices.first,
            items: [
              for (final v in _voices)
                DropdownMenuItem(value: v, child: Text(v)),
            ],
            onChanged: _s.ttsMode == 'cloud'
                ? (v) => _apply(() => _s.ttsVoice = v!)
                : null,
          ),
          const SizedBox(height: 16),
          Text('本地语速：${_s.ttsRate.toStringAsFixed(2)}'),
          Slider(
            value: _s.ttsRate.clamp(0.5, 2).toDouble(),
            min: 0.5,
            max: 2,
            divisions: 30,
            label: _s.ttsRate.toStringAsFixed(2),
            onChanged: (v) => _apply(() => _s.ttsRate = v),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: _trying ? null : _preview,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('试听'),
          ),
          const SizedBox(height: 12),
          Text(
            '说明：云端模式请求失败会自动用本地 TTS 兜底；本地模式使用系统内置语音引擎，无需联网。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
