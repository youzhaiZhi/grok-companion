import 'dart:math' as math;

import 'mathx.dart';

/// 待机导演：空闲一段时间后，以 idle 为底随机插播轻柔短表情；
/// 只允许呼吸/眨眼/凝视/轻摆，绝不触发 hop/旋转（插播期间关闭 autoTricks）。
class IdleDirector {
  IdleDirector({
    this.gentleSet = const ['curious', 'happy', 'shy', 'playful'],
  });

  final List<String> gentleSet;

  double _lastActivity = 0;
  double _startThreshold = 15000;
  bool _primed = false;
  double _nextInsertAt = 0;
  String? _insertKind;
  double _insertEndsAt = -1;

  /// 用户输入/发送/任何交互都调用：立即中断插播并重新计时。
  void notifyUserEvent(double now) {
    _lastActivity = now;
    _startThreshold = rand(12000, 18000);
    _primed = false;
    _insertKind = null;
    _insertEndsAt = -1;
  }

  String? get currentInsert => _insertKind;

  /// 每帧调用。[enabled] = 当前无会话进行。
  /// 返回需要切换的表情 id（含插播结束回 idle），无动作返回 null。
  String? update(
    double now, {
    required bool enabled,
    bool reduceMotion = false,
  }) {
    if (!enabled) {
      _primed = false;
      _insertKind = null;
      _insertEndsAt = -1;
      return null;
    }

    if (!_primed) {
      if (now - _lastActivity >= _startThreshold) {
        _primed = true;
        _nextInsertAt = now;
      } else {
        return null;
      }
    }

    // 减动态：不插播情绪，仅保留 idle 本身的眨眼级微动。
    if (reduceMotion) return null;

    if (_insertKind != null && now >= _insertEndsAt) {
      _insertKind = null;
      _nextInsertAt = now + rand(8000, 20000);
      return 'idle';
    }

    if (_insertKind == null && now >= _nextInsertAt) {
      _insertKind = gentleSet[math.Random().nextInt(gentleSet.length)];
      _insertEndsAt = now + rand(1600, 3200);
      return _insertKind;
    }

    return null;
  }
}
