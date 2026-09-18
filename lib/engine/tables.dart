import 'dart:math' show max;

class EyeTune {
  const EyeTune({
    this.size = 0.86,
    this.gap = 1.18,
    this.height = 1,
    this.eyeWidth = 0.96,
    this.eyeHeight = 0.92,
  });

  final double size;
  final double gap;
  final double height;
  final double eyeWidth;
  final double eyeHeight;
}

class PoseTune {
  const PoseTune({
    this.turn = 17,
    this.tilt = -14,
    this.roll = 29,
    this.scale = 1,
  });

  final double turn;
  final double tilt;
  final double roll;
  final double scale;
}

class Tables {
  Tables._();

  static const List<String> lifecycleStates = [
    'sleeping', 'waking', 'idle', 'listening', 'thinking',
    'searching', 'working',
  ];

  static const List<String> reactionStates = [
    'excited', 'surprised', 'suspicious', 'angry', 'drowsy', 'happy',
    'curious', 'confused', 'bored', 'proud', 'shy', 'sad', 'laughing',
    'scared', 'playful', 'celebrate',
  ];

  /// 23 个用户可见的默认表情。
  static const List<String> presetStates = [
    ...lifecycleStates,
    ...reactionStates,
  ];

  /// 内部状态，不出现在表情库网格。
  static const String writing = 'writing';

  static const Map<String, String> cnNames = {
    'sleeping': '安睡',
    'waking': '苏醒',
    'idle': '待机',
    'listening': '倾听',
    'thinking': '思考',
    'searching': '搜寻',
    'working': '工作',
    'excited': '兴奋',
    'surprised': '惊讶',
    'suspicious': '怀疑',
    'angry': '生气',
    'drowsy': '困倦',
    'happy': '开心',
    'curious': '好奇',
    'confused': '困惑',
    'bored': '无聊',
    'proud': '得意',
    'shy': '害羞',
    'sad': '难过',
    'laughing': '大笑',
    'scared': '害怕',
    'playful': '俏皮',
    'celebrate': '庆祝',
    'writing': '书写',
  };

  static const Map<String, List<int>> eyePlaylist = {
    'sleeping': [13, 22, 4],
    'waking': [13],
    'idle': [0, 8],
    'listening': [10, 1, 19],
    'thinking': [8, 16, 14, 17, 5],
    'searching': [15, 9, 3, 20, 12, 18],
    'working': [7, 16, 11, 10],
    'excited': [2, 17, 21, 3, 11],
    'surprised': [3, 21],
    'suspicious': [14, 5, 23],
    'angry': [7, 16],
    'drowsy': [4, 22, 13],
    'happy': [2, 11, 17, 19],
    'curious': [3, 21, 0, 15],
    'confused': [14, 5, 8],
    'bored': [4, 22, 0],
    'proud': [15, 8, 2],
    'shy': [0, 24, 13],
    'sad': [4, 13, 22],
    'laughing': [2, 11, 17],
    'scared': [3, 21],
    'playful': [2, 17, 11, 8],
    'celebrate': [2, 8, 17],
    'writing': [15, 9],
  };

  static const Map<String, List<double>> eyeHoldMs = {
    'sleeping': [6000, 10000],
    'waking': [800, 800],
    'idle': [9000, 16000],
    'listening': [2800, 5000],
    'thinking': [2000, 3600],
    'searching': [1000, 1800],
    'working': [1800, 3200],
    'excited': [1100, 2000],
    'surprised': [2500, 4000],
    'suspicious': [2600, 4500],
    'angry': [2200, 3800],
    'drowsy': [4000, 8000],
    'happy': [2500, 4500],
    'curious': [1800, 3200],
    'confused': [2200, 3800],
    'bored': [3500, 6000],
    'proud': [3500, 6000],
    'shy': [3000, 5500],
    'sad': [4000, 7000],
    'laughing': [1200, 2400],
    'scared': [900, 1800],
    'playful': [1500, 3000],
    'celebrate': [1400, 2600],
    'writing': [4000, 8000],
  };

  /// null 表示该状态不进行周期性眨眼。
  static const Map<String, List<double>?> blinkMs = {
    'sleeping': null,
    'waking': null,
    'idle': [6000, 14000],
    'listening': [3000, 7000],
    'thinking': [3500, 7000],
    'searching': [1600, 4000],
    'working': [2800, 5500],
    'excited': [2000, 4000],
    'surprised': [1800, 3500],
    'suspicious': [4500, 8000],
    'angry': [3500, 7000],
    'drowsy': null,
    'happy': [2500, 5000],
    'curious': [2500, 5500],
    'confused': [2800, 5500],
    'bored': [4000, 8000],
    'proud': [3500, 7000],
    'shy': [3000, 6000],
    'sad': [4000, 8000],
    'laughing': [2500, 5000],
    'scared': [1200, 3000],
    'playful': [2000, 4500],
    'celebrate': [2200, 4500],
    'writing': null,
  };

  static const List<String> onboardingMoods = [
    'curious', 'happy', 'playful', 'excited',
    'listening', 'proud', 'laughing', 'shy',
  ];

  /// 弹簧常数：[freq, damp]。
  static const Map<String, List<double>> springs = {
    'spin': [5, 0.9],
    'x': [3.5, 1],
    'y': [4, 1],
    'squash': [10, 0.8],
    'blink': [26, 1],
    'eyeScale': [9, 0.85],
    'gazeX': [13, 1],
    'gazeY': [13, 1],
    'overlay': [14, 1],
    'overlayMix': [11, 1],
    'shape': [10, 1],
  };

  static const EyeTune faceTune = EyeTune();
  static const PoseTune pose = PoseTune();
  static const PoseTune poseHome = PoseTune(turn: 33, tilt: -19, roll: 38);
  static const bool uniformEyes = true;

  static final Set<String> vStates = {'happy', 'excited', 'proud'};
  static final Set<String> bStates = {'playful'};
  static final Set<String> winkStates = {
    'idle', 'happy', 'excited', 'curious', 'playful',
  };

  static const Map<String, double> shapeZoom = {
    'blob': 0.92, 'pebble': 0.96, 'squircle': 0.84, 'tablet': 1,
    'wedge': 0.94, 'hex': 0.94, 'cloud': 1, 'teardrop': 1,
  };

  /// 用户与 AI 可切换的 8 个策展形态。
  static const List<String> curatedShapes = [
    'blob', 'pebble', 'squircle', 'tablet', 'wedge', 'hex',
    'cloud', 'teardrop',
  ];

  static const Map<String, String> shapeCnNames = {
    'blob': '团子',
    'pebble': '卵石',
    'squircle': '方圆',
    'tablet': '胶囊板',
    'wedge': '楔形',
    'hex': '六边',
    'cloud': '云朵',
    'teardrop': '水滴',
  };

  static const List<String> paletteIds = [
    'black', 'brown', 'red', 'orange', 'yellow', 'green', 'cyan',
    'blue', 'violet', 'magenta', 'gray',
  ];

  static const Map<String, String> colorCnNames = {
    'black': '墨黑',
    'brown': '棕褐',
    'red': '红色',
    'orange': '橙色',
    'yellow': '明黄',
    'green': '青绿',
    'cyan': '青色',
    'blue': '蓝色',
    'violet': '紫色',
    'magenta': '品红',
    'gray': '灰色',
  };

  static const double viewScale = 259 / 229;
  static const double viewMinX = -15;
  static const double viewMinY = -15;
  static const double viewWidth = 259;
  static const double viewHeight = 259;
  static const double viewHalf = viewWidth / 2;
  static const double viewMid = viewMinX + viewHalf;

  static const Map<String, double> overlayZoom = {
    'dots': 1.5,
    'pencil': 1.18,
  };

  static const String eyeBg = '#F3EFE6';

  static double shapeZoomOf(String name) => shapeZoom[name] ?? 1;
  static double poseScaleOf(String name) => shapeZoomOf(name) * viewScale;
  static double shapeEyeScaleOf(String name) =>
      shapeZoom['blob']! / shapeZoomOf(name);
  static double overlayViewZoom(String? kind, double scale) =>
      kind == null
          ? 1
          : max(overlayZoom[kind]! / max(scale, 1), 1);
}
