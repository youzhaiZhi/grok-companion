import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/character.dart';
import '../../engine/geometry.dart';
import '../../services/settings_store.dart';
import '../stage/grok_stage.dart';

class PreviewPage extends StatefulWidget {
  const PreviewPage({
    super.key,
    required this.settingsStore,
    required this.id,
    required this.cnName,
    this.custom,
  });

  final SettingsStore settingsStore;
  final String id;
  final String cnName;
  final RegisteredExpression? custom;

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  StageController? _stage;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    final raw = await rootBundle.loadString('assets/geo/grok_geo.json');
    final stage = StageController(GrokGeometry.fromJsonString(raw));
    if (widget.custom != null) {
      stage.character.registerCustom(widget.custom!);
    }
    // 直接以目标表情作为初始状态，第一帧即该表情，不经过 idle 与过渡。
    stage.character.initializeAs(widget.id, 0);
    if (mounted) {
      setState(() {
        _stage = stage;
        _ready = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text('${widget.cnName} · ${widget.id}')),
      body: Column(
        children: [
          SizedBox(height: 280, child: GrokStage(controller: _stage!)),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('播放中'),
            subtitle: Text(
              widget.custom == null
                  ? '系统预设表情：眼型序列、姿态与眨眼节奏由引擎编排。'
                  : '自定义表情：基于预设锚点并应用强度/眼睑/形态/颜色偏移。',
            ),
          ),
        ],
      ),
    );
  }
}
