import 'body.dart';
import 'geometry.dart';
import 'mathx.dart';
import 'pose.dart';

/// 角色每帧渲染快照（供 CustomPainter 直接消费）。
class CharacterView {
  CharacterView({
    required this.bodyPath,
    required this.tx,
    required this.ty,
    required this.rot,
    required this.sx,
    required this.sy,
  });

  final String bodyPath;
  final double tx;
  final double ty;
  final double rot;
  final double sx;
  final double sy;
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

    ctx = PoseCtx(0);
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

  late PoseCtx ctx;

  void start(double now) {
    t0 = now;
    stateAt = now;
  }

  void setStateName(String name) {
    state = name;
    stateAt = _now;
    ctx = PoseCtx(stateAt);
  }

  double _now = 0;

  void setShape(String name) {
    if (name == shapeName) return;
    shapeName = name;
    shapeSpring = Spring(0);
  }

  /// 推进一帧。[now] 毫秒。
  CharacterView step(double now) {
    _now = now;
    if (t0 == 0) start(now);

    final mt = (now - t0) / 1000;
    final dtState = (now - stateAt) / 1000;

    final pose = applyPose(state, mt, dtState, now, ctx, blinkX: 1);

    spin.t = pose.spin;
    txSpring.t = pose.tx;
    tySpring.t = pose.ty;
    squash.t = pose.squash;

    if (ctx.tyKick != 0) {
      tySpring.v += ctx.tyKick;
      ctx.tyKick = 0;
    }
    if (ctx.spinKick != 0) {
      spin.v += ctx.spinKick;
      ctx.spinKick = 0;
    }

    final dt = (now - (_last == 0 ? now : _last)) / 1000;
    final stepDt = dt <= 0 ? 1 / 120 : dt;
    final n = springSteps(stepDt);
    final h = stepDt / n;
    for (int i = 0; i < n; i++) {
      stepSpring(spin, 5, 0.9, h);
      stepSpring(txSpring, 3.5, 1, h);
      stepSpring(tySpring, 4, 1, h);
      stepSpring(squash, 10, 0.8, h);
      stepSpring(shapeSpring, 10, 1, h);
    }
    _last = now;

    final bodyPath = geo.shapes[shapeName]!.path;

    return CharacterView(
      bodyPath: bodyPath,
      tx: txSpring.x,
      ty: tySpring.x,
      rot: spin.x,
      sx: squash.x,
      sy: squash.x,
    );
  }

  double _last = 0;
}
