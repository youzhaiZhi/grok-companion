import 'dart:math' as math;

import 'mathx.dart';

class BlinkItem {
  BlinkItem(this.at, this.v);

  double at;
  double v;
}

void queueBlink(List<BlinkItem> q, double now) {
  q.add(BlinkItem(now, 0.05));
  q.add(BlinkItem(now + 70, 0.05));
  q.add(BlinkItem(now + 150, 1.08));
  q.add(BlinkItem(now + 300, 1));
  if (math.Random().nextDouble() < 0.14) {
    q.add(BlinkItem(now + 370, 0.05));
    q.add(BlinkItem(now + 480, 1));
  }
}

double? consumeBlink(List<BlinkItem> q, double now) {
  double? key;
  while (q.isNotEmpty && now >= q.first.at) {
    key = q.removeAt(0).v;
  }
  return key;
}

double winkLid(double base, double now, double winkAt, int winkEye, int i) {
  double lid = math.max(base, 0.04);
  if (i == winkEye && now < winkAt + 320) {
    final xr = (now - winkAt) / 320;
    final fr = xr < 0.42 ? 1 - xr / 0.42 : (xr - 0.42) / 0.58;
    lid = math.max(lid * clamp(fr, 0, 1), 0.04);
  }
  return lid;
}
