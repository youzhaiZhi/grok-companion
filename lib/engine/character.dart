import 'dart:math' as math;

import 'body.dart';
import 'eyes_core.dart';
import 'eyes_paint.dart';
import 'geometry.dart';
import 'mathx.dart';
import 'overlays.dart';
import 'pose.dart';
import 'tables.dart';
import 'tricks.dart';

const double _deg2rad = math.pi / 180;

/// 切换表情时捕获的旧姿态六维快照。
class _PoseSnapshot {
  const _PoseSnapshot(
    this.spin,
    this.tx,
    this.ty,
    this.squash,
    this.lid,
    this.eyeBoost,
  );

  final double spin;
  final double tx;
  final double ty;
  final double squash;
  final double lid;
  final double eyeBoost;
}

class _Transition {
  _Transition(this.from, this.durationMs);

  final _PoseSnapshot from;
  final double durationMs;
  double elapsed = 0;
}


/// 已注册的自定义表情：基于预设锚点 + 受控参数偏移（无坐标字段）。
class RegisteredExpression {
  RegisteredExpression({
    required this.id,
    required this.cnName,
    this.desc = '',
    required this.base,
    this.intensity = 0.5,
    this.holdMs = 2200,
    this.lid,
    this.eyeBoost,
    this.shape,
    this.color,
    this.effects = true,
  });

  final String id;
  final String cnName;
  final String desc;
  final String base;
  final double intensity;
  final double holdMs;
  final double? lid;
  final double? eyeBoost;
  final String? shape;
  final String? color;
  final bool effects;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cnName': cnName,
        'desc': desc,
        'base': base,
        'intensity': intensity,
        'holdMs': holdMs,
        'lid': lid,
        'eyeBoost': eyeBoost,
        'shape': shape,
        'color': color,
        'effects': effects,
      };

  factory RegisteredExpression.fromJson(Map<String, dynamic> j) =>
      RegisteredExpression(
        id: j['id'] as String,
        cnName: j['cnName'] as String,
        desc: (j['desc'] as String?) ?? '',
        base: j['base'] as String,
        intensity: (j['intensity'] as num?)?.toDouble() ?? 0.5,
        holdMs: (j['holdMs'] as num?)?.toDouble() ?? 2200,
        lid: (j['lid'] as num?)?.toDouble(),
        eyeBoost: (j['eyeBoost'] as num?)?.toDouble(),
        shape: j['shape'] as String?,
        color: j['color'] as String?,
        effects: (j['effects'] as bool?) ?? true,
      );
}

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
    required this.overlay,
    required this.colorId,
    required this.prevColorId,
    required this.colorBlend,
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
  final OverlayView overlay;
  final String colorId;
  final String prevColorId;
  final double colorBlend;
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

    colorId = 'black';
    prevColorId = 'black';
    colorBlend = Spring(1);
    overlayState = OverlayState();
    registered = {};
    currentOverride = null;
    reduceMotion = false;
    autoTricks = true;
    showDots = true;
    trickAt = 0;
  }

  final GrokGeometry geo;
  late final BodyShapes bodies;

  String state;
  String shapeName;

  late double t0;
  double stateAt = 0;
  bool _started = false;

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

  late String colorId;
  late String prevColorId;
  late Spring colorBlend;
  late OverlayState overlayState;
  late Map<String, RegisteredExpression> registered;
  RegisteredExpression? currentOverride;
  late bool reduceMotion;
  late bool autoTricks;
  late bool showDots;
  late double trickAt;

  /// 表情切换过渡（姿态/眼睑平滑插值，眼睛 morph 同步）。
  _Transition? _transition;
  double _transitionMix = 1;

  double _now = 0;
  double _last = 0;

  bool get isPreset => Tables.presetStates.contains(state);
  String get effectiveState => currentOverride?.base ?? state;

  void start(double now) {
    t0 = now;
    stateAt = now;
    ctx = PoseCtx(now);
    trickAt = now + rand(2500, 5000);
    _resetTimers(now, effectiveState);
  }

  /// 以指定表情作为初始状态（用于预览页：第一帧就是目标表情，不经过 idle）。
  void initializeAs(String id, double now) {
    final isPreset = Tables.presetStates.contains(id);
    final custom = registered[id];
    if (!isPreset && custom == null) return;

    if (isPreset) {
      state = id;
      currentOverride = null;
    } else {
      state = custom!.id;
      currentOverride = custom;
    }
    final base = effectiveState;
    eyeIdx = 0;
    eyeFrom = 0;
    eyeTo = Tables.eyePlaylist[base]!.first;
    eyeMorph = Spring(1);
    expressionIntensity = clamp(custom?.intensity ?? 0.5, 0, 1);
    t0 = now;
    stateAt = now;
    ctx = PoseCtx(now);
    trickAt = now + rand(9000, 18000);
    _resetTimers(now, base);
    _started = true;
  }

  /// 统一控制通道：id 必须来自预设或已注册自定义；其余参数越界安全忽略。
  bool setExpression(
    String id, {
    double? intensity,
    double? holdMs,
    String? shape,
    String? color,
  }) {
    final isPreset = Tables.presetStates.contains(id);
    final custom = registered[id];
    if (!isPreset && custom == null) return false;

    // 捕获切换前的实际姿态（含弹簧当前值），作为过渡起点。
    final snapshot = _PoseSnapshot(
      spin.x,
      txSpring.x,
      tySpring.x,
      squash.x,
      blink.x,
      eyeScale.x,
    );

    if (isPreset) {
      state = id;
      currentOverride = null;
    } else {
      state = custom!.id;
      currentOverride = custom;
    }
    stateAt = _now;
    ctx = PoseCtx(stateAt);
    eyeIdx = 0;
    overlayState.reset();

    final base = effectiveState;
    _morphEyes(Tables.eyePlaylist[base]!.first, 7);
    _resetTimers(_now, base);

    // 启动过渡（减动态时缩短）；眼睛 morph 与过渡同进度。
    final dur = reduceMotion ? 200.0 : 380.0;
    _transition = _Transition(snapshot, dur)..elapsed = 0;
    _transitionMix = 0;
    if (base == 'waking') {
      blinkQueue.add(BlinkItem(_now + 560, 0.05));
      blinkQueue.add(BlinkItem(_now + 1020, 0.05));
    }

    final reg = currentOverride;
    if (reg != null) {
      if (reg.shape != null) _applyShape(reg.shape!);
      if (reg.color != null) _applyColor(reg.color!);
    }
    expressionIntensity = clamp(intensity ?? reg?.intensity ?? 0.5, 0, 1);
    if (shape != null) _applyShape(shape);
    if (color != null) _applyColor(color);
    return true;
  }

  void setStateName(String name) => setExpression(name);

  void _applyShape(String name) {
    if (!Tables.curatedShapes.contains(name) || name == shapeName) return;
    shapeName = name;
    shapeSpring = Spring(0);
  }

  void setShape(String name) => _applyShape(name);

  void _applyColor(String id) {
    if (!Tables.paletteIds.contains(id) || id == colorId) return;
    prevColorId = colorId;
    colorId = id;
    colorBlend = Spring(0);
  }

  void setColor(String id) => _applyColor(id);

  /// 注册自定义表情（仅供本地库/AI 创作模式调用，聊天通道无法触达）。
  bool registerCustom(RegisteredExpression exp) {
    if (Tables.presetStates.contains(exp.id)) return false;
    if (!Tables.presetStates.contains(exp.base)) return false;
    if (exp.id.isEmpty || exp.id.length > 32) return false;
    registered[exp.id] = exp;
    return true;
  }

  bool unregisterCustom(String id) {
    if (!registered.containsKey(id)) return false;
    registered.remove(id);
    if (currentOverride?.id == id) setExpression('idle');
    return true;
  }

  /// intensity 0–1 → (动作幅度, 眼睛放大)；锚点 0/0.5/1。
  (double, double) intensityMap(double i) {
    final v = clamp(i, 0, 1);
    if (v <= 0.5) {
      final t = v / 0.5;
      return (0.55 + 0.45 * t, 0.95 + 0.05 * t);
    }
    final t = (v - 0.5) / 0.5;
    return (1 + 0.5 * t, 1 + 0.18 * t);
  }

  void _morphEyes(int index, double stiffness) {
    if (index == eyeTo && eyeMorph.t == 1) return;
    eyeFrom = eyeTo;
    eyeTo = index;
    eyeStiffness = stiffness;
    // morph 从 0（旧眼型）走到目标 1（新眼型）；目标必须是 1，不能是 0。
    eyeMorph = Spring(1)
      ..x = 0
      ..v = 0;
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
    if (!_started) {
      start(now);
      _started = true;
    }

    final mt = (now - t0) / 1000;
    final dtState = (now - stateAt) / 1000;
    final base = effectiveState;

    final pose = applyPose(base, mt, dtState, now, ctx, blinkX: blink.x);

    // intensity 映射为动作幅度与眼睛放大；自定义还可叠加 eyeBoost/hold/lid。
    final override = currentOverride;
    final (motionMul, eyeBoostMul) = intensityMap(expressionIntensity);
    final holdScale = override == null ? 1.0 : override.holdMs / 2200;

    // 推进切换过渡：目标从旧快照平滑移动到新 pose，眼睛 morph 同进度。
    final tr = _transition;
    var morphLocked = false;
    if (tr != null) {
      morphLocked = true;
      final realDt = (_last == 0 ? 1 / 120 : (now - _last) / 1000);
      tr.elapsed += realDt * 1000;
      _transitionMix = clamp(tr.elapsed / tr.durationMs, 0, 1);
      if (_transitionMix >= 1) _transition = null;
      // 眼睛 morph 直接跟随过渡进度，并把目标(t)也同步设为 1，
      // 这样过渡结束后弹簧不会把 x 从 ~1 拉回旧目标 0（那是抽搐/回滑的根因）。
      eyeMorph
        ..t = 1
        ..x = _transitionMix
        ..v = 0;
    }

    final newSpin = pose.spin * _deg2rad * motionMul;
    final newTx = pose.tx * motionMul;
    final newTy = pose.ty * motionMul;
    final newSq = pose.squash;
    final newEye =
        pose.eyeBoost * eyeBoostMul * (override?.eyeBoost ?? 1);

    if (tr != null) {
      final e = smoothStep(_transitionMix);
      final f = tr.from;
      spin.t = f.spin + (newSpin - f.spin) * e;
      txSpring.t = f.tx + (newTx - f.tx) * e;
      tySpring.t = f.ty + (newTy - f.ty) * e;
      squash.t = f.squash + (newSq - f.squash) * e;
      eyeScale.t = f.eyeBoost + (newEye - f.eyeBoost) * e;
    } else {
      spin.t = newSpin;
      txSpring.t = newTx;
      tySpring.t = newTy;
      squash.t = newSq;
      eyeScale.t = newEye;
    }

    if (ctx.tyKick != 0) {
      tySpring.v += ctx.tyKick * motionMul;
      ctx.tyKick = 0;
    }
    if (ctx.spinKick != 0) {
      spin.v += ctx.spinKick * _deg2rad * motionMul;
      ctx.spinKick = 0;
    }

    // 眼型播放列表推进。
    if (base != 'waking' && base != 'sleeping') {
      final list = Tables.eyePlaylist[base]!;
      if (list.length > 1 && now >= _eyeUntil) {
        eyeIdx = (eyeIdx + 1) % list.length;
        _morphEyes(
            list[eyeIdx], base == 'searching' || base == 'excited' ? 10 : 6);
        final hold = Tables.eyeHoldMs[base]!;
        _eyeUntil = now + rand(hold[0], hold[1]) * holdScale;
      }
    }

    // 周期性眨眼。
    final cadence = Tables.blinkMs[base];
    if (cadence != null && now >= _blinkUntil) {
      queueBlink(blinkQueue, now);
      _blinkUntil = now + rand(cadence[0], cadence[1]);
    }
    final key = consumeBlink(blinkQueue, now);
    // 眨眼队列里还有未到点的帧时保持当前眼睑值，避免每帧回弹到 pose.lid 造成抖动。
    var lidTarget = key ?? (blinkQueue.isEmpty ? pose.lid : blink.x);
    if (override != null && override.lid != null) {
      lidTarget = clamp(lidTarget * override.lid!, 0, 1.2);
    }
    if (tr != null && key == null) {
      final e = smoothStep(_transitionMix);
      lidTarget = tr.from.lid + (lidTarget - tr.from.lid) * e;
    }
    blink.t = lidTarget;

    // 凝视。
    if (now >= _gazeUntil) {
      final gz = nextGaze(base);
      gazeX.t = gz.x;
      gazeY.t = gz.y;
      _gazeUntil = now + rand(gz.hold[0], gz.hold[1]);
    }

    // 小动作随机调度（V_T/B_T 状态；待机导演可经 autoTricks 关闭）。
    if (now >= trickAt) {
      if (autoTricks &&
          !reduceMotion &&
          (Tables.vStates.contains(base) || Tables.bStates.contains(base)) &&
          spinTurn == null &&
          hopAt < 0 &&
          trick == null) {
        final isV = Tables.vStates.contains(base);
        final z = rand(0, 1);
        if (isV) {
          if (z < 0.55) {
            spinOnce();
          } else {
            playTrick('spinBounce');
          }
        } else if (z < 0.34) {
          playTrick('spinBounce');
        } else if (z < 0.62) {
          hop();
        } else if (z < 0.86) {
          playTrick('spinDizzy');
        } else {
          spinOnce();
        }
      }
      trickAt = now + rand(9000, 18000);
    }

    // 动作：组合特技求值。
    TrickFrame tf;
    if (trick != null) {
      tf = evalTrick(trick, now);
      if (tf.wantHop) hopAt = now;
      if (tf.done) trick = null;
    } else {
      tf = TrickFrame();
    }

    // 跳跃偏移。
    final hopVal = hopY(hopAt, now);
    if (hopVal == null) hopAt = -1;
    final hopOffsetVal = hopVal ?? 0;

    // 叠加特效：thinking dots / writing pencil。
    String? overlayKind;
    if (base == 'thinking' && showDots) overlayKind = 'dots';
    if (base == 'writing') overlayKind = 'pencil';
    final overlay = overlayState.eval(
      overlayKind,
      now,
      stateAt,
      geo.re,
      reduce: reduceMotion,
    );

    // 弹簧积分。
    final dt = (_last == 0 ? 1 / 120 : (now - _last) / 1000);
    final stepDt = dt <= 0 ? 1 / 120 : dt;
    final n = springSteps(stepDt);
    final h = stepDt / n;
    for (int i = 0; i < n; i++) {
      // 过渡期间 eyeMorph 直接跟随过渡进度，不做弹簧积分。
      if (!morphLocked) stepSpring(eyeMorph, eyeStiffness, 1, h);
      if (spinTurn != null) stepSpring(spinTurn!, 5, 0.9, h);
      stepSpring(spin, 5, 0.9, h);
      stepSpring(txSpring, 3.5, 1, h);
      stepSpring(tySpring, 4, 1, h);
      stepSpring(squash, 10, 0.8, h);
      stepSpring(blink, 26, 1, h);
      stepSpring(eyeScale, 9, 0.85, h);
      stepSpring(gazeX, 13, 1, h);
      stepSpring(gazeY, 13, 1, h);
      stepSpring(shapeSpring, 10, 1, h);
      stepSpring(colorBlend, 9, 1, h);
    }
    if (spinTurn != null && spinTurnSettled(spinTurn!)) spinTurn = null;
    if ((colorBlend.t - colorBlend.x).abs() < 0.002 && colorBlend.x > 0.996) {
      prevColorId = colorId;
    }
    _last = now;

    // spinTurn 当前角位移叠加到最终旋转。
    final spinTurnAngle = spinTurn?.x ?? 0;

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
      tx: txSpring.x + tf.yi,
      ty: tySpring.x + hopOffsetVal + tf.ki,
      rot: spin.x + spinTurnAngle + (tf.turn ?? 0) + tf.kr * _deg2rad,
      sx: squash.x,
      sy: squash.x,
      eyePolys: eyePolys,
      eyes: eyes,
      overlay: overlay,
      colorId: colorId,
      prevColorId: prevColorId,
      colorBlend: colorBlend.x,
    );
  }

  // 三个计时器都必须以「当前时刻」为锚点滚动推进（对齐原版 eyeUntil/blinkUntil/gazeUntil）。
  // 若写成「stateAt + 固定偏移」，一旦 now 越过该固定值，条件会逐帧恒真，
  // 于是每帧都重排眼型 / 塞入眨眼 / 重设凝视 → 表现为约两秒后开始的抽搐。
  double _eyeUntil = 0;
  double _blinkUntil = double.infinity;
  double _gazeUntil = 0;

  /// 切换表情（或初始化）后重排计时器。
  void _resetTimers(double now, String base) {
    final hold = Tables.eyeHoldMs[base]!;
    _eyeUntil = now + rand(hold[0], hold[1]);
    final blink = Tables.blinkMs[base];
    _blinkUntil =
        blink == null ? double.infinity : now + rand(blink[0], blink[1]);
    _gazeUntil = now + rand(500, 1400);
  }

  /// 当前表情强度（预设默认 0.5 → 动作 1.0/眼睛 1.0；AI 标签可临时覆盖）。
  double expressionIntensity = 0.5;

  Trick? trick;
  double hopAt = -1;
  Spring? spinTurn;

  /// 触发跳跃。
  void hop() {
    if (!reduceMotion) hopAt = _now;
  }

  /// 触发转一圈。
  void spinOnce({int turns = 1}) {
    if (reduceMotion || spinTurn != null) return;
    spinTurn = makeSpinTurn(turns, randomSign());
  }

  /// 触发组合特技。
  void playTrick(String kind) {
    final t = startTrick(kind, _now, reduceMotion);
    if (t != null) trick = t;
  }
}
