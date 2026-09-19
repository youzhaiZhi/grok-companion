import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../engine/character.dart';
import '../../engine/geometry.dart';
import '../../engine/overlays.dart';
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
    eyePolys: const [],
    eyes: const [],
    overlay: const OverlayView(),
    colorId: 'black',
    prevColorId: 'black',
    colorBlend: 1,
  );

  void tick(double now) {
    view = character.step(now);
    notifyListeners();
  }

  bool setExpression(
    String id, {
    double? intensity,
    double? holdMs,
    String? shape,
    String? color,
  }) =>
      character.setExpression(
        id,
        intensity: intensity,
        holdMs: holdMs,
        shape: shape,
        color: color,
      );

  void hop() => character.hop();
  void spinOnce() => character.spinOnce();
  void playTrick(String kind) => character.playTrick(kind);
}

class GrokStage extends StatefulWidget {
  const GrokStage({super.key, required this.controller, this.onFrame});

  final StageController controller;
  final void Function(double frameMs)? onFrame;

  @override
  State<GrokStage> createState() => _GrokStageState();
}

class _GrokStageState extends State<GrokStage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker((elapsed) {
      final ms = elapsed.inMilliseconds.toDouble();
      widget.controller.tick(ms);
      widget.onFrame?.call(ms);
    })..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _ticker.stop();
    } else if (state == AppLifecycleState.resumed && !_ticker.isTicking) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.controller.geo.viewBox.width),
        painter: _GrokPainter(
          controller: widget.controller,
          ink: _inkColor(context),
          eyeColor: Theme.of(context).scaffoldBackgroundColor,
          brightness: Theme.of(context).brightness,
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
  _GrokPainter({
    required this.controller,
    required this.ink,
    required this.eyeColor,
    required this.brightness,
  }) : super(repaint: controller);

  final StageController controller;
  final Color ink;
  final Color eyeColor;
  final Brightness brightness;

  Color _palette(String id) {
    final hex = brightness == Brightness.dark
        ? controller.geo.palette[id]!.dark
        : controller.geo.palette[id]!.light;
    final v = int.parse(hex.substring(1), radix: 16);
    return Color(0xFF000000 | v);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final view = controller.view;
    if (view.bodyPath.isEmpty) return;
    const r = 259.0 / 2;

    final paletteInk = Color.lerp(
      _palette(view.prevColorId),
      _palette(view.colorId),
      view.colorBlend,
    )!;

    final bodyPaint = Paint()
      ..color = paletteInk
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final eyePaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // 叠加特效绘制于身体之下（被身体覆盖的部分不可见，与 Web 版一致）。
    _paintOverlay(canvas, view, paletteInk);

    final path = _pathCache.putIfAbsent(
      view.bodyPath,
      () => parseSvgPath(view.bodyPath),
    );

    // 身体：以中心为轴施加平移/旋转/挤压。
    canvas.save();
    canvas.translate(view.tx, view.ty);
    canvas.translate(r, r);
    canvas.rotate(view.rot);
    canvas.scale(view.sx, view.sy);
    canvas.translate(-r, -r);
    canvas.drawPath(path, bodyPaint);

    // 眼睛：与页面同色的眼型（视觉上像透出背景），经 3D 姿态仿射变换。
    for (int e = 0; e < view.eyes.length; e++) {
      final t = view.eyes[e];
      if (!t.visible) continue;
      final poly = view.eyePolys[e];
      final eyePath = Path();
      eyePath.moveTo(poly[0][0], poly[0][1]);
      for (int p = 1; p < poly.length; p++) {
        eyePath.lineTo(poly[p][0], poly[p][1]);
      }
      eyePath.close();

      final matrix = Matrix4(
        t.a, t.b, 0, 0,
        t.c, t.d, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
      );

      canvas.save();
      canvas.translate(t.x, t.y);
      canvas.transform(matrix.storage);
      canvas.translate(-t.cx, -t.cy);
      canvas.drawPath(eyePath, eyePaint);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintOverlay(Canvas canvas, CharacterView view, Color ink) {
    final ov = view.overlay;
    if (!ov.active) return;

    if (ov.kind == 'dots') {
      for (final d in ov.dots) {
        canvas.drawCircle(
          Offset(d.x, d.y),
          d.r,
          Paint()
            ..color = ink.withValues(alpha: d.opacity.clamp(0, 1).toDouble())
            ..isAntiAlias = true,
        );
      }
      return;
    }

    if (ov.kind == 'pencil') {
      if (ov.ink.length >= 2) {
        final trail = Path()..moveTo(ov.ink.first[0], ov.ink.first[1]);
        for (final p in ov.ink.skip(1)) {
          trail.lineTo(p[0], p[1]);
        }
        canvas.drawPath(
          trail,
          Paint()
            ..color = ink.withValues(alpha: ov.inkOpacity)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }

      final alpha = ov.pencilOpacity.clamp(0, 1).toDouble();
      if (alpha <= 0.01) return;
      final paint = Paint()
        ..color = ink.withValues(alpha: alpha)
        ..isAntiAlias = true;
      canvas.save();
      canvas.translate(ov.pencilX, ov.pencilY);
      canvas.rotate(ov.pencilRot);
      const halfLen = 29.0;
      const halfW = 7.5;
      final body = Path()
        ..moveTo(-halfLen, -halfW)
        ..lineTo(halfLen - halfW, -halfW)
        ..lineTo(halfLen + 5, 0)
        ..lineTo(halfLen - halfW, halfW)
        ..lineTo(-halfLen, halfW)
        ..close();
      canvas.drawPath(body, paint);
      canvas.drawCircle(
        const Offset(-halfLen, 0),
        halfW,
        paint,
      );
      canvas.drawRect(
        const Rect.fromLTWH(-halfLen - 2, -2, 5, 4),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _GrokPainter oldDelegate) => false;
}

final Map<String, Path> _pathCache = {};

