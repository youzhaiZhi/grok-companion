import 'dart:math' as math;

import 'mathx.dart';

class HopSeg {
  const HopSeg(this.h, this.d);

  final double h;
  final double d;
}

const List<HopSeg> hopSegs = [
  HopSeg(48, 0.5),
  HopSeg(28, 0.382),
  HopSeg(14, 0.27),
  HopSeg(6, 0.177),
];
final double hopDur = hopSegs.map((s) => s.d).fold(0, (a, b) => a + b);

/// 返回跳跃的纵向偏移（负值=向上）；跳完返回 null，未跳返回 0。
double? hopY(double hopAt, double now) {
  if (hopAt < 0) return 0;
  final et = (now - hopAt) / 1000;
  if (et >= hopDur) return null;
  var en = 0.0;
  for (final seg in hopSegs) {
    if (et < en + seg.d) {
      final bn = (et - en) / seg.d;
      return -4 * seg.h * bn * (1 - bn);
    }
    en += seg.d;
  }
  return 0;
}

class Trick {
  Trick(this.kind, double now, this.dir, this.turns) : t0 = now;

  String kind;
  double t0;
  double dir;
  int turns;
}

Trick? startTrick(String kind, double now, bool reduceMotion) {
  if (reduceMotion) return null;
  final dir = randomSign();
  final turns = kind == 'spinDizzy'
      ? rand(3, 5).round().clamp(3, 4)
      : 1;
  return Trick(kind, now, dir, turns);
}

class TrickFrame {
  TrickFrame({
    this.turn,
    this.kr = 0,
    this.yi = 0,
    this.ki = 0,
    this.lidMul,
    this.eyeBoost,
    this.done = false,
    this.wantHop = false,
  });

  double? turn;
  double kr;
  double yi;
  double ki;
  double? lidMul;
  double? eyeBoost;
  bool done;
  bool wantHop;
}

final TrickFrame _empty = TrickFrame(done: true);

TrickFrame evalTrick(Trick? trick, double now) {
  if (trick == null) return _empty;
  final et = (now - trick.t0) / 1000;
  final dir = trick.dir;
  final turns = trick.turns;

  switch (trick.kind) {
    case 'spinDizzy':
      final on = 0.55 + turns * 0.16;
      const bn = 1.5;
      if (et < on) {
        final cn = et / on;
        final turn = turns * 2 * math.pi * dir * (cn * cn);
        return TrickFrame(turn: turn);
      } else if (et < on + bn) {
        final cn = et - on;
        final bi = math.pow(1 - cn / bn, 1.3).toDouble();
        return TrickFrame(
          kr: math.sin(cn * 10) * 17 * dir * bi,
          yi: math.cos(cn * 10) * 10 * dir * bi,
          ki: math.sin(cn * 20) * 3 * bi,
          lidMul: 0.46 + 0.14 * math.sin(cn * 21),
          eyeBoost: 1.03,
        );
      }
      return TrickFrame(done: true);

    case 'spinBounce':
      if (et < 0.7) {
        final turn = 2 * math.pi * dir * easeK2(et / 0.7);
        return TrickFrame(turn: turn);
      }
      return TrickFrame(wantHop: true, done: true);

    default:
      return _empty;
  }
}

/// 生成一个"转 N 圈"弹簧目标。
Spring makeSpinTurn(int turns, double dir) {
  final s = Spring(0);
  s.t = turns * 2 * math.pi * dir;
  return s;
}

bool spinTurnSettled(Spring s) =>
    (s.t - s.x).abs() < 0.004 && s.v.abs() < 0.015;
