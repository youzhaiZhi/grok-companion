import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../engine/character.dart';
import '../../engine/geometry.dart';
import '../../engine/svg_path.dart';

/// 舞台控制器：持有角色，由单 Ticker 驱动；每帧仅通知 painter 重绘，不重建组件树。
class StageController extends ChangeNotifier {
  StageController(this.geo) : character = GrokCharacter(geo);

  final GrokGeometry geo;
  final GrokCharacter character;
  CharacterView view = CharacterView(
    bodyPath: '',
    tx: 0,
    ty: 0,
    rot: 0,
    sx: 1,
    sy: 1,
  );

  void tick(double now) {
    view = character.step(now);
    notifyListeners();
  }

  void setExpression(String id) => character.setStateName(id);
}

class GrokStage extends StatefulWidget {
  const GrokStage({super.key, this.expression, this.geometry});

  final String? expression;

  /// 预加载几何；不提供时从 asset 加载（真机路径）。
  final GrokGeometry? geometry;

  @override
  State<GrokStage> createState() => _GrokStageState();
}

class _GrokStageState extends State<GrokStage>
    with SingleTickerProviderStateMixin {
  GrokGeometry? _geo;
  StageController? _controller;
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _controller?.tick(elapsed.inMilliseconds.toDouble());
    });
    final injected = widget.geometry;
    if (injected != null) {
      _ready(injected);
    } else {
      _load();
    }
  }

  void _ready(GrokGeometry geo) {
    _geo = geo;
    _controller = StageController(geo);
    _ticker.start();
  }

  Future<void> _load() async {
    final raw = await rootBundle.loadString('assets/geo/grok_geo.json');
    final geo = GrokGeometry.fromJsonString(raw);
    if (!mounted) return;
    setState(() => _ready(geo));
  }

  @override
  void didUpdateWidget(covariant GrokStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expression != null && widget.expression != oldWidget.expression) {
      _controller?.setExpression(widget.expression!);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geo = _geo;
    final controller = _controller;
    if (geo == null || controller == null) {
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(geo.viewBox.width),
        painter: _GrokPainter(
          controller: controller,
          ink: _inkColor(context),
        ),
      ),
    );
  }

  Color _inkColor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark ? const Color(0xFFE5E5E5) : const Color(0xFF1A1A1A);
  }
}

class _GrokPainter extends CustomPainter {
  _GrokPainter({required this.controller, required this.ink})
      : super(repaint: controller);

  final StageController controller;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final view = controller.view;
    if (view.bodyPath.isEmpty) return;
    const r = 259.0 / 2;

    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = _pathCache.putIfAbsent(
      view.bodyPath,
      () => parseSvgPath(view.bodyPath),
    );

    // 原生路径已居中：以 Re 为轴施加平移/旋转/挤压，不做尺寸缩放。
    canvas.save();
    canvas.translate(view.tx, view.ty);
    canvas.translate(r, r);
    canvas.rotate(view.rot * 3.14159265 / 180);
    canvas.scale(view.sx, view.sy);
    canvas.translate(-r, -r);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GrokPainter oldDelegate) => false;
}

final Map<String, Path> _pathCache = {};

