import 'dart:math' as math;

final math.Random _rng = math.Random();

class Spring {
  Spring(this.x) : v = 0, t = x;

  double x;
  double v;
  double t;
}

void stepSpring(Spring s, double freq, double damp, double dt) {
  s.v += (-2 * damp * freq * s.v - freq * freq * (s.x - s.t)) * dt;
  s.x += s.v * dt;
  if (!s.x.isFinite || !s.v.isFinite) {
    s.x = s.t;
    s.v = 0;
  }
}

const double kSpringDt = 1 / 120;

int springSteps(double dt) => math.max(1, (dt / kSpringDt).ceil());

double clamp(double n, double a, double b) => math.min(b, math.max(a, n));

int clampI(int n, int a, int b) => math.min(b, math.max(a, n));

double lerp(double a, double b, double t) => a + (b - a) * t;

double rand(double a, double b) => a + _rng.nextDouble() * (b - a);

double randomSign() => _rng.nextDouble() < 0.5 ? -1 : 1;

double hypot(double x, double y) => math.sqrt(x * x + y * y);

double easeK2(double n) =>
    n < 0.5 ? 4 * n * n * n : 1 - math.pow(-2 * n + 2, 3) / 2;

double easeRc(double n) => 1 - math.pow(1 - n, 3).toDouble();

double easeOutBack(double n) =>
    1 + 2.70158 * math.pow(n - 1, 3) + 1.70158 * math.pow(n - 1, 2);

double smoothStep(double n) => n * n * (3 - 2 * n);

double expApproach(double n, double e) =>
    1 - math.exp(math.log(1 - n) * 60 * e);

double expApproachDefault(double n) => expApproach(n, 1 / 60);

typedef Pt = List<double>;

class Face {
  Face({
    required this.x,
    required this.y,
    required this.sx,
    required this.sy,
    required this.eye,
    this.leftDX = 0,
  });

  double x;
  double y;
  double sx;
  double sy;
  double eye;
  double leftDX;

  static Face lerpFace(Face n, Face e, double t) {
    return Face(
      x: n.x + (e.x - n.x) * t,
      y: n.y + (e.y - n.y) * t,
      sx: n.sx + (e.sx - n.sx) * t,
      sy: n.sy + (e.sy - n.sy) * t,
      eye: n.eye + (e.eye - n.eye) * t,
      leftDX: n.leftDX + (e.leftDX - n.leftDX) * t,
    );
  }
}

Pt centroid(List<Pt> pts) {
  double x = 0, y = 0;
  for (final p in pts) {
    x += p[0];
    y += p[1];
  }
  return [x / pts.length, y / pts.length];
}

List<Pt> lerpPoly(List<Pt> a, List<Pt> b, double t) {
  return List<Pt>.generate(
    a.length,
    (i) => [
      a[i][0] + (b[i][0] - a[i][0]) * t,
      a[i][1] + (b[i][1] - a[i][1]) * t,
    ],
  );
}

List<String> _tokenizePath(String d) {
  final re = RegExp(r'[MLCQZmlcqz]|-?\d*\.?\d+(?:e[-+]?\d+)?');
  return re.allMatches(d).map((m) => m.group(0)!).toList();
}

List<Pt> flattenPath(String d, {double step = 4}) {
  final tokens = _tokenizePath(d);
  final out = <Pt>[];
  int r = 0;
  String cmd = '';
  double ox = 0, oy = 0;
  double sx = 0, sy = 0;
  double rd() => double.parse(tokens[r++]);
  void sample(Pt Function(double k) f, double len) {
    final y = math.max(2, (len / step).ceil());
    for (int k = 1; k <= y; k++) {
      out.add(f(k / y));
    }
  }

  while (r < tokens.length) {
    if (RegExp(r'[a-zA-Z]').hasMatch(tokens[r])) {
      cmd = tokens[r++].toUpperCase();
    }
    if (cmd == 'Z') {
      if (hypot(sx - ox, sy - oy) > 0.01) {
        sample(
          (f) => [ox + (sx - ox) * f, oy + (sy - oy) * f],
          hypot(sx - ox, sy - oy),
        );
      }
      ox = sx;
      oy = sy;
      continue;
    }
    if (r >= tokens.length) break;
    if (cmd == 'M') {
      ox = rd();
      oy = rd();
      sx = ox;
      sy = oy;
      out.add([ox, oy]);
      cmd = 'L';
    } else if (cmd == 'L') {
      final x = rd(), y = rd();
      sample((t) => [ox + (x - ox) * t, oy + (y - oy) * t],
          hypot(x - ox, y - oy));
      ox = x;
      oy = y;
    } else if (cmd == 'Q') {
      final x1 = rd(), y1 = rd(), x = rd(), y = rd();
      sample((t) {
        final a = 1 - t;
        return [
          a * a * ox + 2 * a * t * x1 + t * t * x,
          a * a * oy + 2 * a * t * y1 + t * t * y,
        ];
      }, hypot(x1 - ox, y1 - oy) + hypot(x - x1, y - y1));
      ox = x;
      oy = y;
    } else if (cmd == 'C') {
      final x1 = rd(), y1 = rd(), x2 = rd(), y2 = rd(), x = rd(), y = rd();
      sample((t) {
        final a = 1 - t;
        return [
          a * a * a * ox +
              3 * a * a * t * x1 +
              3 * a * t * t * x2 +
              t * t * t * x,
          a * a * a * oy +
              3 * a * a * t * y1 +
              3 * a * t * t * y2 +
              t * t * t * y,
        ];
      }, hypot(x1 - ox, y1 - oy) +
          hypot(x2 - x1, y2 - y1) +
          hypot(x - x2, y - y2));
      ox = x;
      oy = y;
    } else {
      r++;
    }
  }
  return out;
}

typedef SpanAt = List<double> Function(double y);

SpanAt buildSpan(List<Pt> pts, double re, {int e = 160}) {
  double top = double.infinity, bottom = -double.infinity;
  for (final m in pts) {
    if (m[1] < top) top = m[1];
    if (m[1] > bottom) bottom = m[1];
  }
  final range = bottom - top;
  double yAt(int m) => top + range * (m + 0.5) / e;
  final lefts = List<double>.filled(e, 0);
  final rights = List<double>.filled(e, 0);
  for (int m = 0; m < e; m++) {
    final y = yAt(m);
    double h = -double.infinity, rr = double.infinity;
    for (int b = 0; b < pts.length; b++) {
      final p = pts[b];
      final n = pts[(b + 1) % pts.length];
      if ((p[1] <= y) == (n[1] <= y)) continue;
      final xx = p[0] + (n[0] - p[0]) * (y - p[1]) / (n[1] - p[1]);
      if (xx <= re) {
        if (xx > h) h = xx;
      } else if (xx < rr) {
        rr = xx;
      }
    }
    lefts[m] = h.isFinite ? h : re;
    rights[m] = rr.isFinite ? rr : re;
  }
  return (double y) {
    final yy = clamp((y - top) / range * e - 0.5, 0, (e - 1).toDouble());
    final k = yy.floor();
    final f = yy - k;
    final b = math.min(k + 1, e - 1);
    return [
      lefts[k] + (lefts[b] - lefts[k]) * f,
      rights[k] + (rights[b] - rights[k]) * f,
    ];
  };
}

final Map<String, SpanAt> _spanCache = {};

SpanAt spanAt(String path, double re) {
  return _spanCache.putIfAbsent(path, () => buildSpan(flattenPath(path), re));
}

List<double> spanPoly(List<Pt> n, double y, double re) {
  double left = -double.infinity, right = double.infinity;
  for (int r = 0; r < n.length; r++) {
    final a = n[r];
    final o = n[(r + 1) % n.length];
    if ((a[1] <= y) == (o[1] <= y)) continue;
    final x = a[0] + (o[0] - a[0]) * (y - a[1]) / (o[1] - a[1]);
    if (x <= re) {
      if (x > left) left = x;
    } else if (x < right) {
      right = x;
    }
  }
  return [left.isFinite ? left : re, right.isFinite ? right : re];
}

List<double> rot3(double turn, double tilt, double roll) {
  const d = math.pi / 180;
  final ui = math.cos(turn * d), si = math.sin(turn * d);
  final ea = math.cos(tilt * d), ca = math.sin(tilt * d);
  final wo = math.cos(roll * d), c = math.sin(roll * d);
  return [
    wo * ui - c * ca * si, -c * ea, wo * si + c * ca * ui,
    c * ui + wo * ca * si, wo * ea, c * si - wo * ca * ui,
    -ea * si, ca, ea * ui,
  ];
}

List<double> relRot(
  double pTurn, double pTilt, double pRoll,
  double hTurn, double hTilt, double hRoll,
) {
  final gn = rot3(pTurn, pTilt, pRoll);
  final gn2 = rot3(hTurn, hTilt, hRoll);
  List<double> row(int o) => [
        gn[o] * gn2[0] + gn[o + 1] * gn2[1] + gn[o + 2] * gn2[2],
        gn[o] * gn2[3] + gn[o + 1] * gn2[4] + gn[o + 2] * gn2[5],
        gn[o] * gn2[6] + gn[o + 1] * gn2[7] + gn[o + 2] * gn2[8],
      ];
  return [...row(0), ...row(3), ...row(6)];
}

List<double> solidRadii(List<List<double>> solid, double angle, {int n = 96}) {
  final c = math.cos(angle), s = math.sin(angle);
  final rr = solid.map((p) => [p[0] * c + p[2] * s, p[1], p[3]]).toList();
  final raw = List<double>.generate(n, (idx) {
    final u = (idx / n) * math.pi * 2;
    final d = math.cos(u), m = math.sin(u);
    double f = 0;
    for (final h in rr) {
      final v = d * h[0] + m * h[1];
      final b = v * v - (h[0] * h[0] + h[1] * h[1]) + h[2] * h[2];
      if (b <= 0) continue;
      final x = v + math.sqrt(b);
      if (x > f) f = x;
    }
    return f;
  });
  return List<double>.generate(raw.length, (i) {
    final o = raw.length;
    return (raw[(i - 2 + o) % o] +
            4 * raw[(i - 1 + o) % o] +
            6 * raw[i] +
            4 * raw[(i + 1) % o] +
            raw[(i + 2) % o]) /
        16;
  });
}

List<Pt> Function(double yaw) makeTurnAt(
    List<List<double>> solid, List<Pt> ring, double re) {
  final rest = solidRadii(solid, 0);
  return (double yaw) {
    var v = solidRadii(solid, yaw)
        .asMap()
        .entries
        .map((e) => clamp((e.value + 12) / (rest[e.key] + 12), 0.32, 1.5))
        .toList();
    final n = v.length;
    for (int p = 0; p < 3; p++) {
      final prev = v;
      v = List<double>.generate(
        n,
        (a) =>
            (prev[(a - 2 + n) % n] +
                4 * prev[(a - 1 + n) % n] +
                6 * prev[a] +
                4 * prev[(a + 1) % n] +
                prev[(a + 2) % n]) /
            16,
      );
    }
    return ring
        .asMap()
        .entries
        .map((e) => [re + (e.value[0] - re) * v[e.key], re + (e.value[1] - re) * v[e.key]])
        .toList();
  };
}
