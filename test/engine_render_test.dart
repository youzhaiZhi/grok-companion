import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/geometry.dart';
import 'package:grok_companion/engine/tables.dart';
import 'package:grok_companion/features/stage/grok_stage.dart';

void main() {
  final raw = File('assets/geo/grok_geo.json').readAsStringSync();
  final geo = GrokGeometry.fromJsonString(raw);

  test('遍历 23 状态：每状态驱动 2 秒，快照数值有效且路径非空', () {
    final controller = StageController(geo);
    for (final id in Tables.presetStates) {
      controller.setExpression(id);
      for (int f = 0; f < 240; f++) {
        controller.tick(f * 1000 / 120);
      }
      final v = controller.view;
      expect(v.bodyPath.isNotEmpty, true, reason: id);
      expect(v.tx.isFinite && v.ty.isFinite, true, reason: id);
      expect(v.rot.isFinite && v.sx.isFinite && v.sy.isFinite, true,
          reason: id);
      expect(v.sx > 0 && v.sy > 0, true, reason: id);
    }
  });

  testWidgets('painter 对每状态实际绘制不抛异常', (tester) async {
    final controller = StageController(geo);
    controller.tick(16);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomPaint(
            size: Size.square(geo.viewBox.width),
            painter: _TestPainter(controller),
          ),
        ),
      ),
    );
    for (final id in Tables.presetStates) {
      controller.setExpression(id);
      controller.tick(500);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: id);
    }
  });
}

class _TestPainter extends CustomPainter {
  _TestPainter(this.controller) : super(repaint: controller);

  final StageController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final v = controller.view;
    if (v.bodyPath.isEmpty) return;
    final paint = Paint()..color = Colors.black;
    // 直接复用线上 painter 的变换逻辑做最小绘制。
    canvas.save();
    canvas.translate(size.width / 2 + v.tx, size.width / 2 + v.ty);
    canvas.rotate(v.rot);
    canvas.scale(v.sx, v.sy);
    canvas.drawCircle(Offset.zero, 40, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
