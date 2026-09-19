import 'dart:convert';
import 'dart:io';

import '../engine/character.dart';

/// 自定义表情持久化：每个表情一个 JSON 文件，位于应用文档目录下 expressions/。
class ExpressionStore {
  ExpressionStore(this._root);

  final Directory _root;
  Directory get _dir => Directory('${_root.path}${Platform.pathSeparator}expressions');

  Future<void> _ensure() async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
  }

  Future<List<RegisteredExpression>> loadAll() async {
    if (!await _dir.exists()) return [];
    final out = <RegisteredExpression>[];
    for (final f in await _dir.list().where((e) => e is File).toList()) {
      try {
        final j = json.decode(await (f as File).readAsString());
        out.add(RegisteredExpression.fromJson(j as Map<String, dynamic>));
      } catch (_) {
        // 损坏文件安全跳过。
      }
    }
    return out;
  }

  Future<void> save(RegisteredExpression exp) async {
    await _ensure();
    final f = File('${_dir.path}${Platform.pathSeparator}${exp.id}.json');
    await f.writeAsString(json.encode(exp.toJson()));
  }

  Future<bool> delete(String id) async {
    final f = File('${_dir.path}${Platform.pathSeparator}$id.json');
    if (!await f.exists()) return false;
    await f.delete();
    return true;
  }
}
