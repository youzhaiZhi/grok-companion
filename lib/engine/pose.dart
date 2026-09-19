import 'dart:math' as math;

import 'mathx.dart';

class PoseCtx {
  PoseCtx(double now)
      : nodUntil = now + 1800,
        nodEnd = 0,
        angryShakeUntil = 0,
        impulseAt = now + rand(500, 1200),
        tyKick = 0,
        spinKick = 0,
        forceSleepEye = false,
        wakeEye = null,
        wakeBlink = false,
        wakingBlinked = false,
        slumpAt = 0,
        stAt = now + rand(6000, 10000),
        wantPn = null,
        wantBlink = false;

  double nodUntil;
  double nodEnd;
  double angryShakeUntil;
  double impulseAt;
  double tyKick;
  double spinKick;
  bool forceSleepEye;
  List<double>? wakeEye;
  bool wakeBlink;
  bool wakingBlinked;
  double slumpAt;
  double stAt;
  List<double>? wantPn;
  bool wantBlink;
}

class PoseResult {
  PoseResult({
    required this.spin,
    required this.tx,
    required this.ty,
    required this.squash,
    required this.lid,
    required this.eyeBoost,
  });

  double spin;
  double tx;
  double ty;
  double squash;
  double lid;
  double eyeBoost;
}

PoseResult applyPose(
  String state,
  double mt,
  double dtState,
  double now,
  PoseCtx ctx, {
  required double blinkX,
}) {
  const pt = 0.0;
  double lid = 1;
  double eyeBoost = 1;
  double spin = pt;
  double tx = 0;
  double ty = 0;
  double squash = 1;

  switch (state) {
    case 'sleeping':
      final en = math.min(dtState / 2, 1.0);
      final zt = math.sin(clamp(dtState / 0.5, 0, 1) * math.pi);
      spin = pt + 4 * en + math.sin(mt * 0.25) * 2;
      tx = -2 * en;
      ty = 8 * en + math.sin(mt * 0.55) * 3 - zt * 5;
      squash = 1 + math.sin(mt * 0.55) * 0.016 + zt * 0.05;
      if (dtState < 1.2) {
        final dn = math.min(1, dtState);
        lid = math.max(0.08, 1 - dn * (1 + 0.15 * math.sin(dtState * 6.5)));
      } else {
        lid = 0.08;
        if (blinkX < 0.18) ctx.forceSleepEye = true;
      }
      break;

    case 'waking':
      if (dtState < 0.5) {
        lid = 0.07;
        ty = 6;
        ctx.wakeEye = [3, 12];
      } else if (dtState < 1.2) {
        lid = 1;
        eyeBoost = 1.12;
        ty = -5;
        spin = pt;
        squash = 1.04;
      } else if (dtState < 2.2) {
        ty = 0;
        squash = 1;
        ctx.wakeEye = [0, 7];
      } else {
        final et = math.min((dtState - 2.2) / 0.8, 1.0);
        ctx.wakeEye = [0, 7];
        spin = pt + math.sin(et * math.pi * 3) * 6 * (1 - et);
        ty = math.sin(mt * 0.9) * 2;
      }
      break;

    case 'idle':
      spin = pt + math.sin(mt * 0.5) * 1.5 + math.sin(mt * 0.17) * 0.6;
      tx = math.sin(mt * 0.27) * 1;
      ty = math.sin(mt * 0.85) * 1.2;
      squash = 1 + math.sin(mt * 0.85) * 0.007;
      break;

    case 'listening':
      spin = pt + 8 + math.sin(mt * 0.5) * 1.5;
      tx = 2;
      ty = -2 + math.sin(mt * 0.8) * 0.8;
      squash = 1.015;
      if (now >= ctx.nodUntil) {
        ctx.nodUntil = now + rand(1800, 3200);
        ctx.nodEnd = now + 380;
      }
      if (now < ctx.nodEnd) {
        final et = 1 - (ctx.nodEnd - now) / 380;
        ty += math.sin(et * math.pi) * 4.5;
        spin += math.sin(et * math.pi) * 2;
      }
      break;

    case 'thinking':
      spin = pt - 9 + math.sin(mt * 0.35) * 5;
      tx = math.sin(mt * 0.3) * 5;
      ty = math.sin(mt * 0.6) * 2.5;
      break;

    case 'searching':
      final et = math.sin(mt * 1.3);
      spin = pt + et * 13;
      tx = et * 7;
      ty = math.sin(mt * 1.7) * 3;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, randomSign()];
        ctx.stAt = now + rand(4000, 7000);
      }
      break;

    case 'working':
      final et = math.sin(mt * math.pi * 2 * 1.6);
      spin = pt + 4 + et * 2.5;
      tx = 3;
      ty = 1.5 + math.max(0, et) * 3;
      squash = 1 - math.max(0, et) * 0.02;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, 1];
        ctx.stAt = now + rand(6000, 9000);
      }
      break;

    case 'excited':
      final et = (mt * 2.2) % 1;
      final en = math.sin(et * math.pi);
      ty = -en * 10 + 2;
      squash = et < 0.1
          ? 0.92
          : et < 0.3
              ? 1.05
              : 1;
      tx = math.sin(mt * 1.1) * 4;
      eyeBoost = 1.06;
      spin = pt + math.sin(mt * math.pi * 2 * 1.1) * 7;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, randomSign()];
        ctx.stAt = now + rand(2800, 5000);
      }
      break;

    case 'surprised':
      final et = math.min(dtState / 1.2, 1.0);
      tx = -4 * (1 - et);
      ty = -8 * (1 - et);
      squash = dtState < 0.2 ? 1.08 : 1;
      eyeBoost = 1.15 - et * 0.08;
      spin = pt + math.sin(mt * 11) * 1.5 * (1 - et);
      break;

    case 'suspicious':
      spin = pt - 6 + math.sin(mt * 0.3) * 3;
      tx = math.sin(mt * 0.25) * -4;
      ty = 1 + math.sin(mt * 0.45) * 1.2;
      lid = 0.85;
      if (now >= ctx.impulseAt) {
        ctx.spinKick = 30;
        ctx.impulseAt = now + rand(4000, 7000);
      }
      break;

    case 'angry':
      if (now >= ctx.impulseAt) {
        ctx.angryShakeUntil = now + 420;
        ctx.tyKick = 70;
        ctx.impulseAt = now + rand(1800, 3200);
      }
      spin = pt +
          (now < ctx.angryShakeUntil ? math.sin(now * 0.05) * 4.5 : 0);
      ty = 3.5;
      squash = 0.975;
      break;

    case 'drowsy':
      spin = pt + math.sin(mt * 0.32) * 2.5;
      tx = math.sin(mt * 0.2) * 1.5;
      ty = 6 + math.sin(mt * 0.36) * 2.2;
      squash = 1 + math.sin(mt * 0.36) * 0.022;
      lid = 0.34 + math.sin(mt * 0.8) * 0.07;
      if (now >= ctx.nodUntil && ctx.slumpAt == 0) ctx.slumpAt = now;
      if (ctx.slumpAt != 0) {
        final en = (now - ctx.slumpAt) / 1000;
        const zt = 1.7, dn = 0.3, on = 1.5;
        if (en < zt) {
          final bn = en / zt, cn = bn * bn;
          final bi = math.sin(bn * math.pi * 2.5) * 2.2 * (1 - bn);
          ty = 6 + cn * 19 + bi;
          spin = pt + cn * 10;
          lid = 0.34 - cn * (0.34 - 0.04);
          squash = 1 - cn * 0.045;
        } else if (en < zt + dn) {
          final bn = (en - zt) / dn, cn = math.sin(bn * math.pi);
          ty = 25 - cn * 7;
          spin = pt + 10 - cn * 4;
          lid = 0.04 + cn * 0.42;
        } else if (en < zt + dn + on) {
          final bn = (en - zt - dn) / on;
          final cn = 1 - math.pow(1 - bn, 2.2).toDouble();
          ty = 25 - 19 * cn;
          spin = pt + 10 * (1 - cn);
          lid = 0.46 + (0.34 - 0.46) * cn;
          if (bn > 0.32 && bn < 0.46) lid = 0.05;
        } else {
          ctx.slumpAt = 0;
          ctx.nodUntil = now + rand(1500, 3500);
        }
      }
      break;

    case 'happy':
      final et = math.sin(mt * 2.4);
      spin = pt + math.sin(mt * 1.2) * 3;
      tx = math.sin(mt * 1.1) * 2.5;
      ty = -et.abs() * 3;
      squash = 1 + et * 0.02;
      eyeBoost = 1.05;
      break;

    case 'curious':
      spin = pt + 10 + math.sin(mt * 0.7) * 6;
      tx = math.sin(mt * 0.6) * 5;
      ty = -2 + math.sin(mt * 0.9) * 1.5;
      squash = 1.01;
      eyeBoost = 1.08;
      if (now >= ctx.nodUntil) {
        ctx.nodUntil = now + rand(1600, 2800);
        ctx.nodEnd = now + 440;
      }
      if (now < ctx.nodEnd) {
        final et = 1 - (ctx.nodEnd - now) / 440;
        tx += math.sin(et * math.pi) * 8;
        spin += math.sin(et * math.pi) * 5;
      }
      break;

    case 'confused':
      final et = math.sin(mt * 0.8);
      spin = pt + et * 12;
      tx = et * 3;
      ty = math.sin(mt * 0.5) * 2;
      lid = 0.9;
      if (now >= ctx.impulseAt) {
        ctx.spinKick = 22;
        ctx.impulseAt = now + rand(2600, 4200);
      }
      break;

    case 'bored':
      spin = pt - 3 + math.sin(mt * 0.25) * 4;
      tx = math.sin(mt * 0.2) * 4;
      ty = 5 + math.sin(mt * 0.35) * 1.5;
      lid = 0.6;
      eyeBoost = 0.98;
      if (now >= ctx.impulseAt) {
        ctx.nodEnd = now + 600;
        ctx.impulseAt = now + rand(4000, 7000);
      }
      if (now < ctx.nodEnd) {
        final et = 1 - (ctx.nodEnd - now) / 600;
        squash = 1 + math.sin(et * math.pi) * 0.05;
        ty += math.sin(et * math.pi) * 3;
      }
      break;

    case 'proud':
      spin = pt + math.sin(mt * 0.4) * 2.5;
      tx = math.sin(mt * 0.35) * 2;
      ty = -4 + math.sin(mt * 0.6);
      squash = 1.03;
      eyeBoost = 1.02;
      lid = 0.9;
      break;

    case 'shy':
      spin = pt - 8 + math.sin(mt * 0.5) * 3;
      tx = -3 + math.sin(mt * 0.4) * 2;
      ty = 3;
      squash = 0.98;
      eyeBoost = 0.95;
      lid = 0.85;
      break;

    case 'sad':
      spin = pt + 3 + math.sin(mt * 0.3) * 2;
      tx = math.sin(mt * 0.25) * 1.5;
      ty = 7 + math.sin(mt * 0.4);
      squash = 0.97;
      lid = 0.7;
      eyeBoost = 0.97;
      break;

    case 'laughing':
      final et = math.sin(mt * math.pi * 2 * 3.2);
      spin = pt + et * 4;
      tx = math.sin(mt * 2) * 2;
      ty = -et.abs() * 5;
      squash = 1 + et * 0.03;
      lid = 0.7;
      break;

    case 'scared':
      spin = pt + math.sin(now * 0.04) * 2;
      tx = -2 + math.sin(now * 0.05) * 1.5;
      ty = 2 + math.sin(mt * 1.5);
      squash = 0.97;
      eyeBoost = 1.12;
      lid = 1.05;
      break;

    case 'playful':
      spin = pt + math.sin(mt * 1.4) * 8;
      tx = math.sin(mt * 1.1) * 4;
      ty = -math.sin(mt * 2.2).abs() * 3;
      squash = 1 + math.sin(mt * 2.2) * 0.015;
      eyeBoost = 1.06;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, randomSign()];
        ctx.stAt = now + rand(3500, 6000);
      }
      break;

    case 'celebrate':
      ty = -math.sin(mt * 1.6).abs() * 2.5;
      eyeBoost = 1.1;
      lid = 1.1;
      break;

    case 'writing':
      break;

    default:
      break;
  }

  return PoseResult(
    spin: spin,
    tx: tx,
    ty: ty,
    squash: squash,
    lid: lid,
    eyeBoost: eyeBoost,
  );
}

class Gaze {
  Gaze(this.x, this.y, this.hold);

  double x;
  double y;
  List<double> hold;
}

Gaze nextGaze(String state) {
  switch (state) {
    case 'idle':
      return Gaze(0, 0, [2500, 5500]);
    case 'listening':
      return Gaze(
        rand(-0.3, 0.3) * 15,
        rand(-0.25, 0.25) * 9,
        [2200, 4200],
      );
    case 'thinking':
      return Gaze(
        randomSign() * rand(0.5, 1) * 15,
        -rand(0.4, 1) * 9,
        [1500, 2800],
      );
    case 'searching':
      return Gaze(
        randomSign() * rand(0.7, 1) * 15,
        rand(-1, 1) * 9,
        [550, 1150],
      );
    case 'working':
      return Gaze(
        rand(-0.4, 0.4) * 15,
        rand(0.4, 1) * 9,
        [1200, 2400],
      );
    case 'excited':
      return Gaze(rand(-1, 1) * 15, rand(-1, 0.3) * 9, [700, 1400]);
    case 'surprised':
      return Gaze(0, 0, [1600, 2600]);
    case 'suspicious':
      return Gaze(randomSign() * 15, 0.3 * 9, [2200, 4200]);
    case 'angry':
      return Gaze(rand(-0.2, 0.2) * 15, 0.2 * 9, [1800, 3200]);
    case 'drowsy':
      return Gaze(rand(-0.4, 0.4) * 15, rand(0.4, 1) * 9, [2500, 4500]);
    case 'happy':
      return Gaze(rand(-0.7, 0.7) * 15, -rand(0, 0.6) * 9, [1800, 3400]);
    case 'curious':
      return Gaze(
        randomSign() * rand(0.6, 1) * 15,
        rand(-1, 1) * 9,
        [950, 1900],
      );
    case 'confused':
      return Gaze(
        randomSign() * rand(0.5, 1) * 15,
        rand(-0.6, 1) * 9,
        [1100, 2300],
      );
    case 'bored':
      return Gaze(
        randomSign() * rand(0.7, 1) * 15,
        rand(0.4, 0.9) * 9,
        [3000, 6000],
      );
    case 'proud':
      return Gaze(rand(-0.3, 0.3) * 15, -rand(0.3, 0.7) * 9, [2600, 4600]);
    case 'shy':
      return Gaze(randomSign() * rand(0.6, 1) * 15, rand(0.5, 1) * 9, [2000, 4000]);
    case 'sad':
      return Gaze(rand(-0.3, 0.3) * 15, rand(0.6, 1) * 9, [2800, 5000]);
    case 'laughing':
      return Gaze(rand(-0.5, 0.5) * 15, -rand(0.2, 0.6) * 9, [800, 1700]);
    case 'scared':
      return Gaze(
        randomSign() * rand(0.7, 1) * 15,
        rand(-0.6, 0.6) * 9,
        [450, 1050],
      );
    case 'playful':
      return Gaze(randomSign() * rand(0.5, 1) * 15, -rand(0, 0.6) * 9, [900, 1800]);
    default:
      return Gaze(rand(-0.4, 0.4) * 15, rand(-0.3, 0.3) * 9, [2500, 5000]);
  }
}
