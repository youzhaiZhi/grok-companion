import 'dart:convert';

import '../engine/character.dart';
import '../engine/mathx.dart';
import '../engine/tables.dart';

const List<String> _forbiddenKeys = [
  'points',
  'coords',
  'path',
  'vertices',
  'geometry',
  'polygon',
];

/// 校验并清洗 AI 生成的表情草稿：多余字段忽略，越界值 clamp，
/// 出现坐标类字段或缺必填字段则拒绝（返回 null）。
RegisteredExpression? validateCustomDraft(
  Map<String, dynamic> j, {
  required String fallbackId,
}) {
  for (final k in j.keys) {
    if (_forbiddenKeys.contains(k)) return null;
  }

  final cnName = j['cnName'];
  final base = j['base'];
  if (cnName is! String ||
      cnName.trim().isEmpty ||
      cnName.trim().length > 12) {
    return null;
  }
  if (base is! String || !Tables.presetStates.contains(base)) return null;

  double intensity = 0.5;
  if (j['intensity'] is num) {
    intensity = clamp((j['intensity'] as num).toDouble(), 0, 1);
  }

  double holdMs = 2200;
  final h = j['holdMs'] ?? j['hold'];
  if (h is num) holdMs = clamp(h.toDouble(), 800, 8000);

  double? lid;
  if (j['lid'] is num) lid = clamp((j['lid'] as num).toDouble(), 0, 1);

  double? eyeBoost;
  if (j['eyeBoost'] is num) {
    eyeBoost = clamp((j['eyeBoost'] as num).toDouble(), 0.8, 1.3);
  }

  String? shape;
  if (j['shape'] is String) {
    final s = j['shape'] as String;
    if (!Tables.curatedShapes.contains(s)) return null;
    shape = s;
  }

  String? color;
  if (j['color'] is String) {
    final c = j['color'] as String;
    if (!Tables.paletteIds.contains(c)) return null;
    color = c;
  }

  var effects = true;
  if (j['effects'] is bool) effects = j['effects'] as bool;

  final desc = j['desc'] is String ? j['desc'] as String : '';

  return RegisteredExpression(
    id: fallbackId,
    cnName: cnName.trim(),
    desc: desc,
    base: base,
    intensity: intensity,
    holdMs: holdMs,
    lid: lid,
    eyeBoost: eyeBoost,
    shape: shape,
    color: color,
    effects: effects,
  );
}

/// 从可能含解释文字的 AI 回复中截取首个完整 JSON 对象。
Map<String, dynamic>? extractJsonObject(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var inStr = false;
  var esc = false;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (inStr) {
      if (esc) {
        esc = false;
      } else if (ch == r'\') {
        esc = true;
      } else if (ch == '"') {
        inStr = false;
      }
      continue;
    }
    if (ch == '"') {
      inStr = true;
    } else if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        try {
          final j = json.decode(text.substring(start, i + 1));
          return j is Map<String, dynamic> ? j : null;
        } catch (_) {
          return null;
        }
      }
    }
  }
  return null;
}
