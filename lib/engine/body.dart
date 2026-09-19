import 'dart:math' as math;

import 'geometry.dart';
import 'mathx.dart';

/// 将形状路径展平后，按 n=96 个极角求每方向外轮廓半径，得到"极坐标环"。
List<Pt> polarRing(List<Pt> pts, double r, {int n = 96}) {
  return List<Pt>.generate(n, (t) {
    final s = (t / n) * math.pi * 2;
    final c0 = math.cos(s);
    final s0 = math.sin(s);
    double o = 0;
    for (int l = 0; l < pts.length; l++) {
      final a = pts[l];
      final u = pts[(l + 1) % pts.length];
      final d0 = a[0] - r;
      final m = a[1] - r;
      final f = u[0] - r;
      final h = u[1] - r;
      final y = (f - d0) * s0 - (h - m) * c0;
      if (y.abs() < 1e-9) continue;
      final k = (d0 * s0 - m * c0) / -y;
      if (k < 0 || k > 1) continue;
      final v = (d0 + (f - d0) * k) * c0 + (m + (h - m) * k) * s0;
      if (v > o) o = v;
    }
    return [r + c0 * o, r + s0 * o];
  });
}

List<Pt> lerpRing(List<Pt> a, List<Pt> b, double t) {
  return List<Pt>.generate(
    a.length,
    (i) => [
      a[i][0] + (b[i][0] - a[i][0]) * t,
      a[i][1] + (b[i][1] - a[i][1]) * t,
    ],
  );
}

class ShapeMetrics {
  ShapeMetrics({
    required this.face,
    required this.ring,
    required this.tilt,
  });

  final Face face;
  final List<Pt> ring;
  final double tilt;
}

class BodyShapes {
  BodyShapes(this.geo);

  final GrokGeometry geo;
  final Map<String, List<Pt>> _flatCache = {};
  final Map<String, List<Pt>> _ringCache = {};
  final Map<String, ShapeMetrics> _metricsCache = {};

  List<Pt> flattened(String shapeId) {
    return _flatCache.putIfAbsent(shapeId, () {
      final path = geo.shapes[shapeId]!.path;
      return flattenPath(path);
    });
  }

  List<Pt> ring(String shapeId) {
    return _ringCache.putIfAbsent(
      shapeId,
      () => polarRing(flattened(shapeId), geo.re),
    );
  }

  ShapeMetrics metrics(String shapeId) {
    return _metricsCache.putIfAbsent(shapeId, () {
      final shape = geo.shapes[shapeId]!;
      return ShapeMetrics(
        face: shape.face,
        ring: ring(shapeId),
        tilt: shape.tiltScale,
      );
    });
  }
}
