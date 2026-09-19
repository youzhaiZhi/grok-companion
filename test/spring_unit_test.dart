import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/mathx.dart';
import 'package:grok_companion/engine/tricks.dart';

void main() {
  test('spinTurn spring reaches target', () {
    final s = makeSpinTurn(1, 1);
    // 模拟 2 秒，每 4ms。
    for (int f = 0; f < 500; f++) {
      stepSpring(s, 5, 0.9, 0.004);
    }
    // ignore: avoid_print
    print('after 2s: x=${s.x} (target ${s.t})');
    expect(s.x.abs() > 5, true);
  });
}
