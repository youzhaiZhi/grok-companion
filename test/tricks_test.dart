import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/geometry.dart';
import 'package:grok_companion/features/stage/grok_stage.dart';

double deg(double rad) => rad * 180 / math.pi;

void main() {
  final raw = File('assets/geo/grok_geo.json').readAsStringSync();
  final geo = GrokGeometry.fromJsonString(raw);

  test('hop：相对位置产生明显向上峰值（约 48）', () {
    final c = StageController(geo);
    c.tick(10);
    final baseTy = c.view.ty;
    c.hop();
    double maxUpDelta = 0;
    for (int f = 0; f < 340; f++) {
      c.tick((10 + f * 4).toDouble());
      final d = c.view.ty - baseTy;
      if (d < maxUpDelta) maxUpDelta = d;
    }
    expect(maxUpDelta < -30, true, reason: '向上峰值 delta=$maxUpDelta');
  });

  test('spinOnce：转过约一圈（角位移峰值 >180°）', () {
    final c = StageController(geo);
    c.tick(10);
    c.spinOnce();
    double maxRot = 0;
    for (int f = 0; f < 400; f++) {
      c.tick((10 + f * 4).toDouble());
      if (c.view.rot.abs() > maxRot.abs()) maxRot = c.view.rot;
    }
    expect(deg(maxRot).abs() > 180, true, reason: 'maxRot=${deg(maxRot)}°');
  });

  test('spinDizzy：连续旋转 3~4 圈', () {
    final c = StageController(geo);
    c.tick(10);
    c.playTrick('spinDizzy');
    double maxRot = 0;
    for (int f = 0; f < 800; f++) {
      c.tick((10 + f * 4).toDouble());
      if (c.view.rot.abs() > maxRot.abs()) maxRot = c.view.rot;
    }
    expect(deg(maxRot).abs() > 720, true, reason: 'maxRot=${deg(maxRot)}°');
  });

  test('spinBounce：转一圈后触发跳跃', () {
    final c = StageController(geo);
    c.tick(10);
    final baseTy = c.view.ty;
    c.playTrick('spinBounce');
    double maxRot = 0, minTyDelta = 0;
    for (int f = 0; f < 500; f++) {
      c.tick((10 + f * 4).toDouble());
      if (c.view.rot.abs() > maxRot.abs()) maxRot = c.view.rot;
      final d = c.view.ty - baseTy;
      if (d < minTyDelta) minTyDelta = d;
    }
    expect(deg(maxRot).abs() > 180, true, reason: 'maxRot=${deg(maxRot)}°');
    expect(minTyDelta < -25, true, reason: 'minTyDelta=$minTyDelta');
  });
}
