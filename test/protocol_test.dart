import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/engine/character.dart';
import 'package:grok_companion/engine/tables.dart';
import 'package:grok_companion/services/expression_protocol.dart';

void main() {
  test('单词标签：正常文本与指令分离，标签被剥离', () {
    final p = ExpressionProtocol();
    final out = p.feed('你好呀[[happy]]真开心');
    expect(out.text, '你好呀真开心');
    expect(out.commands.single.id, 'happy');
  });

  test('逐字符分片：跨 chunk 标签仍能正确解析', () {
    final p = ExpressionProtocol();
    final visible = StringBuffer();
    final ids = <String>[];
    for (final ch in '嘿[[shy]]'.split('')) {
      final out = p.feed(ch);
      visible.write(out.text);
      ids.addAll(out.commands.map((c) => c.id));
    }
    expect(visible.toString(), '嘿');
    expect(ids, ['shy']);
  });

  test('多字符分片 + 标签中途跨 chunk', () {
    final p = ExpressionProtocol();
    final chunks = ['先说[[curio', 'us]]结尾'];
    final o1 = p.feed(chunks[0]);
    final o2 = p.feed(chunks[1]);
    expect(o1.text, '先说');
    expect(o1.commands, isEmpty);
    expect(o2.text, '结尾');
    expect(o2.commands.single.id, 'curious');
  });

  test('JSON 对象：字段解析，越界 intensity/hold 被 clamp', () {
    final p = ExpressionProtocol();
    final out = p.feed(
      '[[{"base":"excited","intensity":9,"hold":99999,'
      '"shape":"cloud","color":"violet"}]]',
    );
    expect(out.text, '');
    final c = out.commands.single;
    expect(c.id, 'excited');
    expect(c.intensity, 1);
    expect(c.holdMs, 8000);
    expect(c.shape, 'cloud');
    expect(c.color, 'violet');
  });

  test('非法标签三类：未知 id / 非白名单 shape-color / 坏 JSON，全部安全丢弃', () {
    final p = ExpressionProtocol();
    expect(p.feed('[[unknownState]]').commands, isEmpty);
    expect(p.feed('[[{"base":"happy","shape":"starship"}]]').commands, isEmpty);
    final out = p.feed('x[[{"base":"happy","color":"ultraviolet"}]]y');
    expect(out.commands, isEmpty);
    expect(out.text, 'xy');
    expect(p.feed('[[{broken').commands, isEmpty);
  });

  test('单个 [ 歧义：chunk 末尾挂起，下一字符决定', () {
    final p = ExpressionProtocol();
    final o1 = p.feed('a[');
    expect(o1.text, 'a');
    final o2 = p.feed('[happy]]b');
    expect(o2.text, 'b');
    expect(o2.commands.single.id, 'happy');

    final q = ExpressionProtocol();
    final r1 = q.feed('a[');
    final r2 = q.feed('b');
    expect(r1.text + r2.text, 'a[b');
  });

  test('未闭合标签：文本不泄漏标签内容，reset 后正常', () {
    final p = ExpressionProtocol();
    final out = p.feed('可见[[happy');
    expect(out.text, '可见');
    expect(out.commands, isEmpty);
    p.reset();
    expect(p.feed('继续').text, '继续');
  });

  test('目录生成：23 预设齐全、自定义出现、无临场新建措辞与坐标字段', () {
    final catalog = buildExpressionCatalog(
      customs: [
        RegisteredExpression(id: 'gentle_x', cnName: '轻X', base: 'happy'),
      ],
    );
    for (final id in Tables.presetStates) {
      expect(catalog.contains(id), true, reason: id);
    }
    expect(catalog.contains('gentle_x'), true);
    expect(catalog.contains('轻X'), true);
    for (final s in Tables.curatedShapes) {
      expect(catalog.contains(s), true);
    }
    expect(catalog.contains('可临场新建'), false);
    expect(catalog.contains('坐标'), false);
    expect(catalog.contains('coords'), false);
    expect(catalog.contains('不得创建新表情'), true);
  });
}
