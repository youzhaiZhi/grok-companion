import 'dart:convert';

import '../engine/character.dart';
import '../engine/mathx.dart';
import '../engine/tables.dart';

class ExpressionCommand {
  ExpressionCommand(
    this.id, {
    this.intensity,
    this.holdMs,
    this.shape,
    this.color,
  });

  final String id;
  final double? intensity;
  final double? holdMs;
  final String? shape;
  final String? color;
}

class ProtocolOutput {
  ProtocolOutput(this.text, this.commands);

  final String text;
  final List<ExpressionCommand> commands;
}

/// 增量解析 [[id]] / [[{json}]]：闭合瞬间产出指令，标签从可见文本剥离。
class ExpressionProtocol {
  ExpressionProtocol({Iterable<String>? customIds})
      : _valid = <String>{...Tables.presetStates, ...?customIds};

  final Set<String> _valid;
  final StringBuffer _visible = StringBuffer();
  final StringBuffer _tag = StringBuffer();
  bool _inTag = false;
  bool _holdBracket = false;
  bool _holdClose = false;

  void updateCatalog(Iterable<String> ids) {
    _valid
      ..clear()
      ..addAll(Tables.presetStates)
      ..addAll(ids);
  }

  void reset() {
    _visible.clear();
    _tag.clear();
    _inTag = false;
    _holdBracket = false;
    _holdClose = false;
  }

  ProtocolOutput feed(String chunk) {
    var input = chunk;
    final commands = <ExpressionCommand>[];

    if (_holdBracket) {
      _holdBracket = false;
      if (input.startsWith('[')) {
        _inTag = true;
        input = input.substring(1);
      } else {
        _visible.write('[');
      }
    }

    if (_holdClose) {
      _holdClose = false;
      if (input.startsWith(']')) {
        _closeTag(commands);
        input = input.substring(1);
      } else {
        _tag.write(']');
      }
    }

    final units = input.runes.toList();
    for (var i = 0; i < units.length; i++) {
      final ch = String.fromCharCode(units[i]);
      if (_inTag) {
        if (ch == ']' &&
            i + 1 < units.length &&
            units[i + 1] == 93) {
          _closeTag(commands);
          i++;
        } else if (ch == ']' && i == units.length - 1) {
          _holdClose = true;
        } else {
          _tag.write(ch);
        }
      } else if (ch == '[') {
        if (i + 1 < units.length && units[i + 1] == 91) {
          _inTag = true;
          _tag.clear();
          i++;
        } else if (i == units.length - 1) {
          _holdBracket = true;
        } else {
          _visible.write(ch);
        }
      } else {
        _visible.write(ch);
      }
    }

    final text = _visible.toString();
    _visible.clear();
    return ProtocolOutput(text, commands);
  }

  void _closeTag(List<ExpressionCommand> out) {
    final content = _tag.toString().trim();
    _inTag = false;
    _tag.clear();
    if (content.isEmpty) return;

    if (content.startsWith('{')) {
      try {
        final j = json.decode(content) as Map<String, dynamic>;
        final base = j['base'] ?? j['id'];
        if (base is! String || !_valid.contains(base)) return;

        double? intensity;
        if (j['intensity'] is num) {
          intensity = clamp((j['intensity'] as num).toDouble(), 0, 1);
        }
        double? holdMs;
        final h = j['hold'] ?? j['holdMs'];
        if (h is num) holdMs = clamp(h.toDouble(), 800, 8000);
        String? shape;
        if (j['shape'] != null) {
          if (j['shape'] is String &&
              Tables.curatedShapes.contains(j['shape'])) {
            shape = j['shape'] as String;
          } else {
            return;
          }
        }
        String? color;
        if (j['color'] != null) {
          if (j['color'] is String &&
              Tables.paletteIds.contains(j['color'])) {
            color = j['color'] as String;
          } else {
            return;
          }
        }
        out.add(ExpressionCommand(
          base,
          intensity: intensity,
          holdMs: holdMs,
          shape: shape,
          color: color,
        ));
      } catch (_) {
        // 非法 JSON：整条丢弃。
      }
      return;
    }

    if (_valid.contains(content)) out.add(ExpressionCommand(content));
  }
}

/// 生成注入系统提示词的表情目录：仅含允许字段，明确只能引用、不得临场新建。
String buildExpressionCatalog({List<RegisteredExpression> customs = const []}) {
  final b = StringBuffer('可用表情（只能使用下列 id，不得编造，不得创建新表情）：\n');
  for (final id in Tables.presetStates) {
    b.write('$id（${Tables.cnNames[id]}）；');
  }
  b.write('\n表情标签用法（标签对用户不可见）：[[happy]] 或 '
      '[[{"base":"happy","intensity":0.8,"hold":2200,"shape":"cloud","color":"violet"}]]。\n'
      '参数范围：intensity 0~1；hold 800~8000 毫秒；'
      'shape 仅可取 ${Tables.curatedShapes.join("/")}；'
      'color 仅可取 ${Tables.paletteIds.join("/")}。');
  if (customs.isNotEmpty) {
    b.write('\n用户自定义表情（同样只能引用）：');
    for (final c in customs) {
      b.write('${c.id}（${c.cnName}，基于 ${c.base}）；');
    }
  }
  return b.toString();
}
