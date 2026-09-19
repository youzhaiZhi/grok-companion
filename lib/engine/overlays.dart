import 'dart:math' as math;

import 'mathx.dart';

class OverlayDot {
  const OverlayDot(this.x, this.y, this.r, this.opacity);

  final double x;
  final double y;
  final double r;
  final double opacity;
}

/// thinking 的 dots 与 writing 的 pencil 的逐帧绘制数据。
class OverlayView {
  const OverlayView({
    this.kind,
    this.dots = const [],
    this.pencilX = 0,
    this.pencilY = 0,
    this.pencilRot = 0,
    this.pencilOpacity = 0,
    this.ink = const [],
    this.inkOpacity = 0,
  });

  final String? kind;
  final List<OverlayDot> dots;
  final double pencilX;
  final double pencilY;
  final double pencilRot;
  final double pencilOpacity;
  final List<Pt> ink;
  final double inkOpacity;

  bool get active => kind != null;
}

const OverlayView _none = OverlayView();

const double _dotR = 22;
const double _dotGap = 62;
const double _pencilMs = 2500;

class OverlayState {
  List<Pt> ink = [];

  void reset() => ink = [];

  OverlayView eval(
    String? kind,
    double now,
    double stateAt,
    double r, {
    bool reduce = false,
  }) {
    if (kind == null) return _none;
    final blend = clamp((now - stateAt) / 260, 0, 1);
    if (blind(blend)) return _none;
    if (kind == 'dots') return _dots(now, stateAt, r, blend, reduce);
    if (kind == 'pencil') return _pencil(now, stateAt, r, blend);
    return _none;
  }

  bool blind(double blend) => blend <= 0.004;

  OverlayView _dots(double now, double stateAt, double r, double blend, bool reduce) {
    final out = <OverlayDot>[];
    for (final slot in [0, 2]) {
      final phase = ((((now - stateAt) / 1400 + 0.119) % 1) + 1) % 1;
      var d = (phase - slot / 3).abs();
      d = math.min(d, 1 - d);
      final g = reduce ? 1.0 : math.exp(-(d * d) / (2 * 0.15 * 0.15));
      final lift = reduce ? 0.0 : g * 9;
      final pop = 1 + (reduce ? 0.0 : (0.84 + 0.22 * g - 1));
      final tone = 1 - (reduce ? 0.0 : 0.5 * (1 - g));
      final x = r + (slot == 0 ? -_dotGap : _dotGap);
      out.add(OverlayDot(x, r - lift, _dotR * pop * blend, g * tone * blend));
    }
    return OverlayView(kind: 'dots', dots: out);
  }

  OverlayView _pencil(double now, double stateAt, double r, double blend) {
    final ptMs = now - stateAt;
    final mt = (((ptMs / _pencilMs) % 1) + 1) % 1;
    double x;
    double y;
    double wig;
    double rot;
    bool lifted;
    if (mt < 0.68) {
      final t = mt / 0.68;
      final lt = t * t * (3 - 2 * t);
      final yn = clamp(t / 0.08, 0, 1) * clamp((1 - t) / 0.08, 0, 1);
      x = -54 + 118 * lt;
      y = 26;
      wig = math.sin(t * 24) * 3.2 * yn;
      rot = 17 + math.sin(ptMs * 6e-4);
      lifted = false;
    } else {
      final t = easeK2((mt - 0.68) / 0.32);
      x = 64 - 118 * t;
      y = 26 - 20 * math.sin(t * math.pi);
      wig = 0;
      rot = 17 - 2 * math.sin(t * math.pi) + math.sin(ptMs * 6e-4);
      lifted = true;
    }

    final px = r + x;
    final py = r + y + wig;
    if (!lifted) {
      final tip = [px, py + 19];
      final last = ink.isEmpty ? null : ink.last;
      if (last == null || hypot(tip[0] - last[0], tip[1] - last[1]) > 2.4) {
        ink.add(tip);
        if (ink.length > 64) ink.removeAt(0);
      } else {
        last[0] = tip[0];
        last[1] = tip[1];
      }
    } else if (ink.isNotEmpty) {
      ink.removeRange(0, math.min(2, ink.length));
    }

    return OverlayView(
      kind: 'pencil',
      pencilX: px,
      pencilY: py,
      pencilRot: rot * math.pi / 180,
      pencilOpacity: clamp(blend * 1.6 - 0.3, 0, 1),
      ink: List<Pt>.from(ink),
      inkOpacity: ink.length < 2 ? 0 : clamp(blend * 1.2, 0, 1),
    );
  }
}
