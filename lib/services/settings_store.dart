import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API Key 加密存储接口（便于测试注入）。
abstract class KeyVault {
  Future<String?> readKey();
  Future<void> writeKey(String value);
}

class SecureKeyVault implements KeyVault {
  SecureKeyVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readKey() => _storage.read(key: 'api_key');

  @override
  Future<void> writeKey(String value) =>
      _storage.write(key: 'api_key', value: value);
}

class InMemoryKeyVault implements KeyVault {
  String? _key;

  @override
  Future<String?> readKey() async => _key;

  @override
  Future<void> writeKey(String value) async => _key = value;
}

/// 应用全部设置。apiKey 不落 SharedPreferences，仅经 KeyVault 加密存储。
class AppSettings {
  AppSettings({
    this.baseUrl = '',
    this.apiKey = '',
    this.model = 'grok-4',
    this.temperature = 0.7,
    this.ttsMode = 'off',
    this.ttsVoice = 'alloy',
    this.ttsRate = 1.0,
    this.allowShapeColor = true,
    this.showDots = true,
    this.reduceMotion = false,
  });

  String baseUrl;
  String apiKey;
  String model;
  double temperature;
  String ttsMode; // off | local | cloud
  String ttsVoice;
  double ttsRate;
  bool allowShapeColor;
  bool showDots;
  bool reduceMotion;

  bool get apiReady => baseUrl.isNotEmpty && apiKey.isNotEmpty;

  AppSettings copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    String? ttsMode,
    String? ttsVoice,
    double? ttsRate,
    bool? allowShapeColor,
    bool? showDots,
    bool? reduceMotion,
  }) {
    return AppSettings(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      ttsMode: ttsMode ?? this.ttsMode,
      ttsVoice: ttsVoice ?? this.ttsVoice,
      ttsRate: ttsRate ?? this.ttsRate,
      allowShapeColor: allowShapeColor ?? this.allowShapeColor,
      showDots: showDots ?? this.showDots,
      reduceMotion: reduceMotion ?? this.reduceMotion,
    );
  }
}

class SettingsStore {
  SettingsStore({SharedPreferences? prefs, KeyVault? vault})
      :
        // 公共命名参数保留为 prefs，故意不使用 this._prefs 形式。
        // ignore: prefer_initializing_formals
        _prefs = prefs,
        _vault = vault ?? SecureKeyVault();

  SharedPreferences? _prefs;
  final KeyVault _vault;

  static SettingsStore? _instance;
  static SettingsStore get instance => _instance!;
  static Future<SettingsStore> init({KeyVault? vault}) async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SettingsStore(prefs: prefs, vault: vault);
    return _instance!;
  }

  Future<AppSettings> load() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    final key = await _vault.readKey() ?? '';
    return AppSettings(
      baseUrl: p.getString('base_url') ?? '',
      apiKey: key,
      model: p.getString('model') ?? 'grok-4',
      temperature: p.getDouble('temperature') ?? 0.7,
      ttsMode: p.getString('tts_mode') ?? 'off',
      ttsVoice: p.getString('tts_voice') ?? 'alloy',
      ttsRate: p.getDouble('tts_rate') ?? 1.0,
      allowShapeColor: p.getBool('allow_shape_color') ?? true,
      showDots: p.getBool('show_dots') ?? true,
      reduceMotion: p.getBool('reduce_motion') ?? false,
    );
  }

  Future<void> save(AppSettings s) async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString('base_url', s.baseUrl);
    await p.setString('model', s.model);
    await p.setDouble('temperature', s.temperature);
    await p.setString('tts_mode', s.ttsMode);
    await p.setString('tts_voice', s.ttsVoice);
    await p.setDouble('tts_rate', s.ttsRate);
    await p.setBool('allow_shape_color', s.allowShapeColor);
    await p.setBool('show_dots', s.showDots);
    await p.setBool('reduce_motion', s.reduceMotion);
    if (s.apiKey.isNotEmpty) await _vault.writeKey(s.apiKey);
  }
}
