import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../engine/character.dart';
import '../../engine/geometry.dart';
import '../../engine/tables.dart';
import '../../services/expression_store.dart';
import '../../services/settings_store.dart';
import '../ai_assist/ai_assist_page.dart';
import '../stage/grok_stage.dart';

const String _previewId = '__preview__';

class CreatorPage extends StatefulWidget {
  const CreatorPage({super.key, required this.settingsStore, this.edit});

  final SettingsStore settingsStore;
  final RegisteredExpression? edit;

  @override
  State<CreatorPage> createState() => _CreatorPageState();
}

class _CreatorPageState extends State<CreatorPage> {
  late final TextEditingController _name;
  late String _base;
  late double _intensity;
  late double _holdMs;
  late bool _useLid;
  late double _lid;
  late bool _useEyeBoost;
  late double _eyeBoost;
  late String? _shape;
  late String? _color;
  late bool _effects;

  StageController? _stage;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _name = TextEditingController(text: e?.cnName ?? '');
    _base = e?.base ?? 'idle';
    _intensity = e?.intensity ?? 0.5;
    _holdMs = e?.holdMs ?? 2200;
    _useLid = e?.lid != null;
    _lid = e?.lid ?? 1;
    _useEyeBoost = e?.eyeBoost != null;
    _eyeBoost = e?.eyeBoost ?? 1;
    _shape = e?.shape;
    _color = e?.color;
    _effects = e?.effects ?? true;
    _setup();
    _name.addListener(_refreshPreview);
  }

  Future<void> _setup() async {
    final raw = await rootBundle.loadString('assets/geo/grok_geo.json');
    final stage = StageController(GrokGeometry.fromJsonString(raw));
    if (mounted) {
      setState(() {
        _stage = stage;
        _ready = true;
        _refreshPreview();
      });
    }
  }

  RegisteredExpression _draft(String id) => RegisteredExpression(
        id: id,
        cnName: _name.text,
        base: _base,
        intensity: _intensity,
        holdMs: _holdMs,
        lid: _useLid ? _lid : null,
        eyeBoost: _useEyeBoost ? _eyeBoost : null,
        shape: _shape,
        color: _color,
        effects: _effects,
      );

  void _refreshPreview() {
    final stage = _stage;
    if (stage == null) return;
    stage.character
      ..unregisterCustom(_previewId)
      ..registerCustom(_draft(_previewId));
    stage.setExpression(_previewId);
  }

  void _change(void Function() f) => setState(() {
        f();
        _refreshPreview();
      });

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 12) {
      _warn('名称需为 1–12 个字符');
      return;
    }
    final store = ExpressionStore(await getApplicationDocumentsDirectory());
    final customs = await store.loadAll();
    if (customs.any((c) => c.cnName == name && c.id != widget.edit?.id)) {
      _warn('已有同名表情，请换个名字');
      return;
    }
    final id =
        widget.edit?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    await store.save(_draft(id));
    if (mounted) Navigator.of(context).pop();
  }

  void _warn(String text) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _aiAssist() async {
    final draft = await Navigator.of(context).push<RegisteredExpression>(
      MaterialPageRoute(
        builder: (_) => AiAssistPage(settingsStore: widget.settingsStore),
      ),
    );
    if (draft == null) return;
    _change(() {
      _base = draft.base;
      _intensity = draft.intensity;
      _holdMs = draft.holdMs;
      _useLid = draft.lid != null;
      _lid = draft.lid ?? 1;
      _useEyeBoost = draft.eyeBoost != null;
      _eyeBoost = draft.eyeBoost ?? 1;
      _shape = draft.shape;
      _color = draft.color;
      _effects = draft.effects;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final title = widget.edit == null ? '新建表情' : '编辑表情';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [TextButton(onPressed: _save, child: const Text('保存'))],
      ),
      body: Column(
        children: [
          SizedBox(height: 220, child: GrokStage(controller: _stage!)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '表情名称（中文，1–12 字）',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _label('锚点预设'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _base,
                    items: [
                      for (final id in Tables.presetStates)
                        DropdownMenuItem(
                          value: id,
                          child: Text('${Tables.cnNames[id]} · $id'),
                        ),
                    ],
                    onChanged: (v) => _change(() => _base = v!),
                  ),
                  _slider(
                    '强度',
                    _intensity,
                    0,
                    1,
                    (v) => _intensity = v,
                    _intensity.toStringAsFixed(2),
                  ),
                  _slider(
                    '停留（毫秒）',
                    _holdMs,
                    800,
                    8000,
                    (v) => _holdMs = v,
                    _holdMs.round().toString(),
                    divisions: 72,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自定义眼睑开合'),
                    value: _useLid,
                    onChanged: (v) => _change(() => _useLid = v),
                  ),
                  if (_useLid)
                    _slider('眼睑', _lid, 0, 1, (v) => _lid = v,
                        _lid.toStringAsFixed(2)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('自定义眼睛放大'),
                    value: _useEyeBoost,
                    onChanged: (v) => _change(() => _useEyeBoost = v),
                  ),
                  if (_useEyeBoost)
                    _slider('眼睛放大', _eyeBoost, 0.8, 1.3,
                        (v) => _eyeBoost = v, _eyeBoost.toStringAsFixed(2)),
                  _label('默认形态（不指定则保持当前）'),
                  _optionRow(
                    Tables.curatedShapes,
                    _shape,
                    Tables.shapeCnNames,
                    (v) => _shape = v,
                  ),
                  const SizedBox(height: 12),
                  _label('默认颜色'),
                  _optionRow(
                    Tables.paletteIds,
                    _color,
                    Tables.colorCnNames,
                    (v) => _color = v,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('允许叠加点缀'),
                    value: _effects,
                    onChanged: (v) => _change(() => _effects = v),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _aiAssist,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('AI 辅助设计'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Text(text, style: const TextStyle(fontSize: 13)),
      );

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    void Function(double) set,
    String display, {
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('$label：$display', style: const TextStyle(fontSize: 13)),
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: (v) => _change(() => set(v)),
        ),
      ],
    );
  }

  Widget _optionRow(
    List<String> ids,
    String? current,
    Map<String, String> names,
    void Function(String?) set,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('不指定'),
          selected: current == null,
          onSelected: (_) => _change(() => set(null)),
        ),
        for (final id in ids)
          ChoiceChip(
            label: Text(names[id] ?? id),
            selected: current == id,
            onSelected: (_) => _change(() => set(id)),
          ),
      ],
    );
  }
}
