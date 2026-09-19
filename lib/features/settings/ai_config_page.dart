import 'package:flutter/material.dart';

import '../../services/llm_service.dart';
import '../../services/settings_store.dart';

class AiConfigPage extends StatefulWidget {
  const AiConfigPage({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<AiConfigPage> createState() => _AiConfigPageState();
}

class _AiConfigPageState extends State<AiConfigPage> {
  late final TextEditingController _url;
  late final TextEditingController _key;
  late final TextEditingController _model;
  double _temperature = 0.7;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    widget.settingsStore.load().then((s) => setState(() {
          _url.text = s.baseUrl;
          _key.text = s.apiKey;
          _model.text = s.model;
          _temperature = s.temperature;
        }));
    _url = TextEditingController();
    _key = TextEditingController();
    _model = TextEditingController();
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cur = await widget.settingsStore.load();
    await widget.settingsStore.save(cur.copyWith(
      baseUrl: _url.text.trim(),
      model: _model.text.trim(),
      temperature: _temperature,
    ));
    if (_key.text.trim().isNotEmpty) {
      final updated = await widget.settingsStore.load();
      updated.apiKey = _key.text.trim();
      await widget.settingsStore.save(updated);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await LlmService().chatOnce(
        baseUrl: _url.text.trim(),
        apiKey: _key.text.trim(),
        model: _model.text.trim(),
        messages: const [ChatMsg('user', 'ping')],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接成功')),
        );
      }
    } on LlmException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败：${e.cnText}')),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('模型与接口'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.example.com/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('温度：${_temperature.toStringAsFixed(2)}'),
          Slider(
            value: _temperature,
            min: 0,
            max: 2,
            divisions: 40,
            label: _temperature.toStringAsFixed(2),
            onChanged: (v) => setState(() => _temperature = v),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: const Text('测试连接'),
          ),
        ],
      ),
    );
  }
}
