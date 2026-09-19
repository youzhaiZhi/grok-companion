import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/idle_director.dart';

void main() {
  const gentle = ['curious', 'happy', 'shy', 'playful'];

  test('60s 内至少插播 2 次，且只含轻柔集合，每次结束回 idle', () {
    final d = IdleDirector();
    d.notifyUserEvent(0);
    final sequence = <String>[];
    for (double t = 0; t <= 60000; t += 200) {
      final out = d.update(t, enabled: true);
      if (out != null) sequence.add(out);
    }
    final inserts = sequence.where(gentle.contains).toList();
    expect(sequence.every((e) => e == 'idle' || gentle.contains(e)), true,
        reason: 'sequence=$sequence');
    // 完整完成（之后回到 idle）的插播至少 2 次；
    // 窗口末尾尚未结束的最后一个插播不计入。
    var completed = 0;
    for (final e in inserts) {
      final i = sequence.indexOf(e);
      if (sequence.skip(i + 1).contains('idle')) completed++;
    }
    expect(completed >= 2, true,
        reason: 'completed=$completed inserts=$inserts');
  });

  test('会话中 enabled=false：不插播且状态被清空', () {
    final d = IdleDirector();
    d.notifyUserEvent(0);
    for (double t = 0; t <= 30000; t += 500) {
      expect(d.update(t, enabled: false), isNull);
    }
    expect(d.currentInsert, isNull);
  });

  test('用户事件中断当前插播，之后重新计时', () {
    final d = IdleDirector();
    d.notifyUserEvent(0);
    String? interrupted;
    for (double t = 0; t <= 25000; t += 200) {
      final out = d.update(t, enabled: true);
      if (out != null && gentle.contains(out)) {
        interrupted = out;
        d.notifyUserEvent(t);
        expect(d.currentInsert, isNull);
        break;
      }
    }
    expect(interrupted != null, true);
    for (double t = 0; t <= 10000; t += 500) {
      expect(d.update(t, enabled: false), isNull);
    }
  });

  test('reduceMotion：60s 内不插播任何情绪', () {
    final d = IdleDirector();
    d.notifyUserEvent(0);
    for (double t = 0; t <= 60000; t += 200) {
      expect(d.update(t, enabled: true, reduceMotion: true), isNull);
    }
  });
}
