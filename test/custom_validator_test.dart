import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grok_companion/services/custom_validator.dart';

void main() {
  const id = 'custom_test';

  test('正常样例：通过，字段保留', () {
    final r = validateCustomDraft(const {
      'cnName': '腼腆期待',
      'desc': '测试',
      'base': 'shy',
      'intensity': 0.72,
      'holdMs': 2600,
      'lid': 0.8,
      'eyeBoost': 1.05,
      'shape': 'cloud',
      'color': 'violet',
      'effects': true,
    }, fallbackId: id);
    expect(r != null, true);
    expect(r!.cnName, '腼腆期待');
    expect(r.base, 'shy');
    expect(r.intensity, closeTo(0.72, 1e-9));
    expect(r.holdMs, 2600);
    expect(r.lid, 0.8);
    expect(r.eyeBoost, 1.05);
    expect(r.shape, 'cloud');
    expect(r.color, 'violet');
  });

  test('攻击样例：坐标类字段一律拒绝', () {
    expect(
      validateCustomDraft(const {
        'cnName': '坏',
        'base': 'idle',
        'points': [[1, 2]],
      }, fallbackId: id),
      isNull,
    );
    expect(
      validateCustomDraft(const {
        'cnName': '坏',
        'base': 'idle',
        'coords': 'x',
      }, fallbackId: id),
      isNull,
    );
  });

  test('未知枚举：shape/color/base 非法时拒绝', () {
    expect(
      validateCustomDraft(const {
        'cnName': '坏',
        'base': 'idle',
        'shape': 'starship',
      }, fallbackId: id),
      isNull,
    );
    expect(
      validateCustomDraft(const {
        'cnName': '坏',
        'base': 'idle',
        'color': 'ultraviolet',
      }, fallbackId: id),
      isNull,
    );
    expect(
      validateCustomDraft(const {
        'cnName': '坏',
        'base': 'madeUp',
      }, fallbackId: id),
      isNull,
    );
  });

  test('超大值被 clamp；多余字段被忽略；缺字段拒绝', () {
    final r = validateCustomDraft(const {
      'cnName': '普通',
      'base': 'happy',
      'intensity': 9,
      'holdMs': 99999,
      'lid': -5,
      'eyeBoost': 50,
      'mystery': 'ignored',
    }, fallbackId: id);
    expect(r != null, true);
    expect(r!.intensity, 1);
    expect(r.holdMs, 8000);
    expect(r.lid, 0);
    expect(r.eyeBoost, 1.3);

    expect(
      validateCustomDraft(const {'cnName': '无锚点'}, fallbackId: id),
      isNull,
    );
    expect(
      validateCustomDraft(const {'base': 'idle'}, fallbackId: id),
      isNull,
    );
    expect(
      validateCustomDraft(const {
        'cnName': '',
        'base': 'idle',
      }, fallbackId: id),
      isNull,
    );
    expect(
      validateCustomDraft(const {
        'cnName': '名字真的太长了啊哈哈哈哈哈哈',
        'base': 'idle',
      }, fallbackId: id),
      isNull,
    );
  });

  test('extractJsonObject：从带解释文字的回复中提取 JSON', () {
    final j = extractJsonObject(
      '好的，这是设计：{"cnName":"开心","base":"happy"} 希望喜欢',
    );
    expect(j != null, true);
    expect(j!['cnName'], '开心');
    expect(extractJsonObject('no json'), isNull);
    expect(extractJsonObject('{"a":1'), isNull);
  });

  test('聊天通道隔离：chat_controller.dart 中无 registerCustom 调用', () async {
    final f = File('lib/services/chat_controller.dart');
    final content = await f.readAsString();
    expect(content.contains('registerCustom'), false);
  });
}
