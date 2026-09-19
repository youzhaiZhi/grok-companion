import 'package:flutter/material.dart';

import '../../engine/character.dart';
import '../../services/custom_validator.dart';
import '../../services/llm_service.dart';
import '../../services/settings_store.dart';

class AiAssistPage extends StatefulWidget {
  const AiAssistPage({super.key, required this.settingsStore});

  final SettingsStore settingsStore;

  @override
  State<AiAssistPage> createState() => _AiAssistPageState();
}

class _AiAssistPageState extends State<AiAssistPage> {
  final TextEditingController _desc = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final s = await widget.settingsStore.load();
    if (!s.apiReady) {
      setState(() => _error = '请先在设置中配置 Base URL 与 API Key');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    const systemPrompt =
        '你是表情设计器。根据用户描述设计一个表情，只能基于给定预设锚点做参数调节，'
        '禁止输出任何坐标/路径/顶点类数据。严格只输出一个 JSON 对象，不要输出解释。'
        'JSON 字段：cnName(中文名称,1-12字)、desc(中文一句话说明)、'
        'base(锚点预设 id)、intensity(0-1)、holdMs(800-8000)、'
        'lid(可选,0-1)、eyeBoost(可选,0.8-1.3)、'
        'shape(可选,仅允许 blob/pebble/squircle/tablet/wedge/hex/cloud/teardrop)、'
        'color(可选,仅允许 black/brown/red/orange/yellow/green/cyan/blue/violet/magenta/gray)、'
        'effects(布尔)。';

    try {
      final raw = await LlmService().chatOnce(
        baseUrl: s.baseUrl,
        apiKey: s.apiKey,
        model: s.model,
        messages: [
          const ChatMsg('system', systemPrompt),
          ChatMsg('user', _desc.text),
        ],
        temperature: 0.8,
      );
      final j = extractJsonObject(raw);
      if (j == null) {
        setState(() {
          _error = '没有从返回中解析出有效的表情定义，请重试';
          _busy = false;
        });
        return;
      }
      final draft = validateCustomDraft(
        j,
        fallbackId:
            'custom_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (draft == null) {
        setState(() {
          _error = '生成的内容含越界或坐标类字段，已拒绝，请重试';
          _busy = false;
        });
        return;
      }
      if (mounted) Navigator.of(context).pop<RegisteredExpression>(draft);
    } on LlmException catch (e) {
      setState(() {
        _error = '生成失败：${e.cnText}';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 辅助设计')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '描述你想要的感觉，例如：腼腆又有点期待、'
              '像中奖后不敢相信的开心',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _desc,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '输入描述…',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13)),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _generate,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('生成表情'),
            ),
          ],
        ),
      ),
    );
  }
}
