import 'dart:math' as math;

import 'geometry.dart';
import 'mathx.dart';
import 'tables.dart';
import 'eyes_core.dart';

/// 身体在给定 y 处的左右内壁（用于约束眼睛不跑出身体）。
typedef BodySpan = List<double> Function(double y);

/// 单只眼睛的最终绘制参数。
class EyeTransform {
  EyeTransform({
    required this.visible,
    required this.x,
    required this.y,
    required this.a,
    required this.b,
    required this.c,
    required this.d,
    required this.cx,
    required this.cy,
  });

  bool visible;

  /// translate(x,y)
  double x;
  double y;

  /// 2D affine matrix [a b; c d]
  double a, b, c, d;

  /// 眼多边形自身质心（translate(-cx,-cy)）。
  double cx, cy;
}

class EyeExtras {
  EyeExtras({this.zr = 0, this.wi = 0});

  double zr;
  double wi;
}

class EyePaintInput {
  EyePaintInput({
    required this.now,
    required this.polys,
    required this.shape,
    required this.face,
    required this.blinkX,
    required this.gazeX,
    required this.gazeY,
    required this.winkAt,
    required this.winkEye,
    required this.eyeBoost,
    required this.extras,
    required this.re,
    required this.bodySpan,
    this.cr,
    this.overlayX = 0,
  });

  double now;
  List<List<Pt>> polys;
  GrokShape shape;
  Face face;
  double blinkX;
  double gazeX;
  double gazeY;
  double winkAt;
  int winkEye;
  double eyeBoost;
  EyeExtras extras;
  double re;
  BodySpan bodySpan;

  /// 相机姿态相对旋转矩阵（9 个数）；null 时退化为 2D。
  List<double>? cr;
  double overlayX;
}

List<EyeTransform> paintEyes(EyePaintInput o) {
  final re = o.re;
  final cr = o.cr;
  final pulse = 1.0;

  final fi = Face(
    x: o.face.x,
    y: o.face.y,
    sx: o.face.sx * Tables.faceTune.gap,
    sy: o.face.sy * Tables.faceTune.height,
    eye: o.face.eye * Tables.faceTune.size,
  );
  const sX = 0.0;

  final cents = [centroid(o.polys[0]), centroid(o.polys[1])];
  double a1 = 0, o1 = 0;
  for (final p in o.polys[0]) {
    a1 = math.max(a1, (p[0] - cents[0][0]).abs());
  }
  for (final p in o.polys[1]) {
    o1 = math.max(o1, (p[0] - cents[1][0]).abs());
  }

  final l1 = (cents[1][0] - (cents[0][0] + sX)).abs() * fi.sx;
  final ee =
      a1 + o1 > 0.5 ? clamp(l1 / (a1 + o1), 0.35, 4) : 4.0;
  final uee = clamp(1.0, 0.25, 4);
  final ox = math.min(clamp(o.eyeBoost, 0.2, 2) * uee, ee / pulse);
  final hee =
      math.min(ox * clamp(Tables.faceTune.eyeWidth, 0.2, 3), ee / pulse);
  final u1 = ox * clamp(Tables.faceTune.eyeHeight, 0.2, 3);

  final top = o.shape.top;
  final bottom = o.shape.bottom;

  final result = <EyeTransform>[];
  for (int i = 0; i < 2; i++) {
    final poly = o.polys[i];
    final gn = cents[i][0], ti = cents[i][1];
    final lid = winkLid(o.blinkX, o.now, o.winkAt, o.winkEye, i);

    final ea = gn + sX;
    double ca = re + fi.x;
    double wo = (ea - re) * fi.sx;
    double km = 1, ree = 0, fee = 0, zee = 1;
    double sre = clamp(
      re + fi.y + (ti - re) * fi.sy,
      top + 2,
      bottom - 2,
    );
    final use3d = cr != null;

    if (use3d) {
      final xr = (ea - re) / re;
      final fr = (re - ti) / re;
      final ia = math.sqrt(math.max(0, 1 - xr * xr - fr * fr));
      final li = cr[0] * xr + cr[1] * fr + cr[2] * ia;
      final bl = cr[3] * xr + cr[4] * fr + cr[5] * ia;
      final io = cr[6] * xr + cr[7] * fr + cr[8] * ia;
      wo = li * re * fi.sx;
      sre = clamp(re + fi.y - bl * re * fi.sy, top + 2, bottom - 2);

      var uo = -fr * xr;
      var tl = 1 - fr * fr;
      var zi = -fr * ia;
      final yo = math.sqrt(uo * uo + tl * tl + zi * zi);
      if (yo < 1e-6) {
        uo = 0; tl = 0; zi = 1;
      } else {
        uo /= yo; tl /= yo; zi /= yo;
      }
      final md = fr * zi - ia * tl;
      final oc = ia * uo - xr * zi;
      final yu = xr * tl - fr * uo;
      final vm = cr[0] * uo + cr[1] * tl + cr[2] * zi;
      final hme = cr[3] * uo + cr[4] * tl + cr[5] * zi;
      final nre = cr[0] * md + cr[1] * oc + cr[2] * yu;
      final ere = cr[3] * md + cr[4] * oc + cr[5] * yu;

      final cre = md, ha = -oc, ci2 = uo, ys = -tl;
      final ku = cre * ys - ci2 * ha;
      final ql = ys / ku;
      final gee = -ci2 / ku;
      final bm = -ha / ku;
      final ire = cre / ku;
      km = nre * ql + vm * bm;
      fee = nre * gee + vm * ire;
      ree = -ere * ql + -hme * bm;
      zee = -ere * gee + -hme * ire;
      final bre = io > 0.02;
      final tre = smoothStep(clamp(io / 0.5, 0, 1));

      // 微动 + 凝视。
      var kj = math.sin(o.now * 42e-5 + i) * 1.4 +
          math.sin(o.now * 0.001 + i * 2) * 0.5;
      final ko = math.sin(o.now * 58e-5 + i) * 0.9;
      kj += o.gazeX + o.extras.zr;
      final ky = ko + o.gazeY + o.extras.wi;

      // turn==null：水平 FrM=Hee（不乘 cc）；垂直 IaM=lid*u1。
      final frM = clamp(hee * pulse, 0.02, 2.4);
      final iaM = clamp(lid * u1 * pulse, 0.02, 2.4);
      final visible = bre && o.overlayX < 0.5;

      final vl = clamp(sre + ky * fi.sy, top + 2, bottom - 2);

      var o2 = -double.infinity, xl = double.infinity;
      for (int pp = 0; pp < poly.length; pp += 2) {
        final frp = (poly[pp][0] - gn) * frM;
        final span = o.bodySpan(vl + (poly[pp][1] - ti) * iaM);
        if (span[0] - frp > o2) o2 = span[0] - frp;
        if (span[1] - frp < xl) xl = span[1] - frp;
      }
      final xre = ca + wo + kj * fi.sx;
      final lx = o2 <= xl ? clamp(xre, o2, xl) : (o2 + xl) / 2;
      final dd = lx + (xre - lx) * (1 - tre);

      result.add(EyeTransform(
        visible: visible,
        x: dd,
        y: vl,
        a: km * frM,
        b: ree * frM,
        c: fee * iaM,
        d: zee * iaM,
        cx: gn,
        cy: ti,
      ));
    }
  }
  return result;
}
