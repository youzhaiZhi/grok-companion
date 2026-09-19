import 'body.dart';
import 'eyes_core.dart';
import 'eyes_paint.dart';
import 'geometry.dart';
import 'mathx.dart';
import 'pose.dart';
import 'tables.dart';

/// 角色每帧渲染快照（供 CustomPainter 直接消费）。
class CharacterView {
  CharacterView({
    required this.bodyPath,
    required this.tx,
    required this.ty,
    required this.rot,
    required this.sx,
    required this.sy,
    required this.eyePolys,
    required this.eyes,
  });

  final String bodyPath;
  final double tx;
  final double ty;
  final double rot;
  final double sx;
  final double sy;

  /// 当前每只眼睛的多边形（已完成眼型 morph）。
  final List<List<Pt>> eyePolys;
  final List<EyeTransform> eyes;
}

class GrokCharacter {
  GrokCharacter(this.geo)
      : state = 'idle',
        shapeName = 'blob' {
    bodies = BodyShapes(geo);
    t0 = 0;
    stateAt = 0;

    spin = Spring(0);
    txSpring = Spring(0);
    tySpring = Spring(0);
    squash = Spring(1);
    shapeSpring = Spring(1);

    blink = Spring(1);
    eyeMorph = Spring(1);
    eyeScale = Spring(1);
    gazeX = Spring(0);
    gazeY = Spring(0);

    ctx = PoseCtx(0);

    eyeFrom = 0;
    eyeTo = 0;
    eyeStiffness = 7;
    eyeIdx = 0;
    blinkQueue = [];
    winkAt = -1e9;
    winkEye = 0;
  }

  final GrokGeometry geo;
  late final BodyShapes bodies;

  String state;
  String shapeName;

  late double t0;
  double stateAt = 0;

  late Spring spin;
  late Spring txSpring;
  late Spring tySpring;
  late Spring squash;
  late Spring shapeSpring;

  late Spring blink;
  late Spring eyeMorph;
  late Spring eyeScale;
  late Spring gazeX;
  late Spring gazeY;

  late PoseCtx ctx;

  int eyeFrom = 0;
  int eyeTo = 0;
  double eyeStiffness = 7;
  int eyeIdx = 0;
  late List<BlinkItem> blinkQueue;
  double winkAt = -1e9;
  int winkEye = 0;

  double _now = 0;
  double _last = 0;

  void start(double now) {
    t0 = now;
    stateAt = now;
    ctx = PoseCtx(now);
  }

  void setStateName(String name) {
    state = name;
    stateAt = _now;
    ctx = PoseCtx(stateAt);
    eyeIdx = 0;
    _morphEyes(Tables.eyePlaylist[name]!.first, 7);
    if (name == 'waking') {
      blinkQueue.add(BlinkItem(_now + 560, 0.05));
      blinkQueue.add(BlinkItem(_now + 1020, 0.05));
    }
  }

  void setShape(String name) {
    if (name == shapeName) return;
    shapeName = name;
    shapeSpring = Spring(0);
  }

  void _morphEyes(int index, double stiffness) {
    eyeFrom = eyeTo;
    eyeTo = index;
    eyeStiffness = stiffness;
    eyeMorph = Spring(0);
  }

  List<Pt> _currentPoly(int i) {
    final a = geo.eyes[eyeFrom][i];
    final b = geo.eyes[eyeTo][i];
    final t = clamp(eyeMorph.x, 0, 1);
    return lerpPoly(a, b, t);
  }

  /// 推进一帧。[now] 毫秒。
  CharacterView step(double now) {
    _now = now;
    if (t0 == 0) start(now);

    final mt = (now - t0) / 1000;
    final dtState = (now - stateAt) / 1000;

    final pose = applyPose(state, mt, dtState, now, ctx, blinkX: blink.x);

    spin.t = pose.spin;
    txSpring.t = pose.tx;
    tySpring.t = pose.ty;
    squash.t = pose.squash;
    eyeScale.t = pose.eyeBoost;

    if (ctx.tyKick != 0) {
      tySpring.v += ctx.tyKick;
      ctx.tyKick = 0;
    }
    if (ctx.spinKick != 0) {
      spin.v += ctx.spinKick;
      ctx.spinKick = 0;
    }

    // 眼型播放列表推进。
    if (state != 'waking' && state != 'sleeping') {
      final list = Tables.eyePlaylist[state]!;
      final hold = Tables.eyeHoldMs[state]!;
      final until = stateAt + _eyeStartOffset + hold[eyeIdx % hold.length];
      if (now >= until && list.length > 1) {
        eyeIdx = (eyeIdx + 1) % list.length;
        _morphEyes(list[eyeIdx], state == 'searching' || state == 'excited' ? 10 : 6);
        _eyeStartOffset = 0;
      }
    }

    // 周期性眨眼。
    final cadence = Tables.blinkMs[state];
    final blinkUntilMs = stateAt + _blinkOffset + (cadence?[0] ?? 0);
    if (cadence != null && now >= blinkUntilMs) {
      queueBlink(blinkQueue, now);
      _blinkOffset = cadence[1];
    }
    final key = consumeBlink(blinkQueue, now);
    blink.t = key ?? pose.lid;

    // 凝视。
    final gazeUntilMs = stateAt + _gazeOffset;
    if (now >= gazeUntilMs) {
      final gz = nextGaze(state);
      gazeX.t = gz.x;
      gazeY.t = gz.y;
      _gazeOffset = gz.hold[0];
    }

    // 弹簧积分。
    final dt = (_last == 0 ? 1 / 120 : (now - _last) / 1000);
    final stepDt = dt <= 0 ? 1 / 120 : dt;
    final n = springSteps(stepDt);
    final h = stepDt / n;
    for (int i = 0; i < n; i++) {
      stepSpring(eyeMorph, eyeStiffness, 1, h);
      stepSpring(spin, 5, 0.9, h);
      stepSpring(txSpring, 3.5, 1, h);
      stepSpring(tySpring, 4, 1, h);
      stepSpring(squash, 10, 0.8, h);
      stepSpring(blink, 26, 1, h);
      stepSpring(eyeScale, 9, 0.85, h);
      stepSpring(gazeX, 13, 1, h);
      stepSpring(gazeY, 13, 1, h);
      stepSpring(shapeSpring, 10, 1, h);
    }
    _last = now;

    final eyePolys = [_currentPoly(0), _currentPoly(1)];

    final shape = geo.shapes[shapeName]!;
    final cr = relRot(
      Tables.pose.turn, Tables.pose.tilt, Tables.pose.roll,
      Tables.poseHome.turn, Tables.poseHome.tilt, Tables.poseHome.roll,
    );
    final input = EyePaintInput(
      now: now,
      polys: eyePolys,
      shape: shape,
      face: shape.face,
      blinkX: blink.x,
      gazeX: gazeX.x,
      gazeY: gazeY.x,
      winkAt: winkAt,
      winkEye: winkEye,
      eyeBoost: eyeScale.x,
      extras: EyeExtras(),
      re: geo.re,
      bodySpan: (y) => spanAt(shape.path, geo.re)(y),
      cr: cr,
    );
    final eyes = paintEyes(input);

    return CharacterView(
      bodyPath: shape.path,
      tx: txSpring.x,
      ty: tySpring.x,
      rot: spin.x,
      sx: squash.x,
      sy: squash.x,
      eyePolys: eyePolys,
      eyes: eyes,
    );
  }

  double _eyeStartOffset = 0;
  double _blinkOffset = 3000;
  double _gazeOffset = 1000;
}
