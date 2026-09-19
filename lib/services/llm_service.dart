import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatMsg {
  const ChatMsg(this.role, this.content);

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

enum LlmErrorKind { network, auth, badRequest, server }

class LlmException implements Exception {
  LlmException(this.kind, [this.message = '']);

  final LlmErrorKind kind;
  final String message;

  String get cnText => switch (kind) {
        LlmErrorKind.network => '网络连接失败，请检查网络或接口地址',
        LlmErrorKind.auth => 'API Key 无效或没有权限',
        LlmErrorKind.badRequest => '请求参数有误，请检查模型与接口设置',
        LlmErrorKind.server => '服务暂时不可用，请稍后再试',
      };

  @override
  String toString() => 'LlmException($kind, $message)';
}

LlmErrorKind _kindForStatus(int code) {
  if (code == 401 || code == 403) return LlmErrorKind.auth;
  if (code >= 500) return LlmErrorKind.server;
  return LlmErrorKind.badRequest;
}

class LlmService {
  LlmService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String _endpoint(String baseUrl, String path) {
    final b = baseUrl.trim();
    final root = b.endsWith('/') ? b.substring(0, b.length - 1) : b;
    return '$root$path';
  }

  Map<String, String> _headers(String apiKey) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  /// OpenAI 兼容流式对话：产出 delta 文本；错误以 LlmException 进入流。
  Stream<String> streamChat({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatMsg> messages,
    double temperature = 0.7,
  }) {
    final controller = StreamController<String>();
    final body = json.encode({
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
      'stream': true,
    });

    final req = http.Request(
      'POST',
      Uri.parse(_endpoint(baseUrl, '/chat/completions')),
    )
      ..headers.addAll(_headers(apiKey))
      ..body = body;

    Future(() async {
      final response = await _client.send(req);
      if (response.statusCode != 200) {
        final text = await response.stream.transform(utf8.decoder).join();
        throw LlmException(_kindForStatus(response.statusCode), text);
      }
      final lineSub = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          final t = line.trim();
          if (!t.startsWith('data:')) return;
          final payload = t.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') return;
          try {
            final j = json.decode(payload) as Map<String, dynamic>;
            final choices = j['choices'] as List;
            if (choices.isNotEmpty) {
              final d = choices[0]['delta'];
              if (d is Map && d['content'] is String) {
                controller.add(d['content'] as String);
              }
            }
          } catch (_) {
            // 跳过无法解析的行。
          }
        },
        onError: (Object e) => throw e,
      );

      controller.onCancel = () {
        lineSub.cancel();
      };
      await lineSub.asFuture();
    }).then((_) {
      controller.close();
    }).catchError((Object e) {
      if (controller.isClosed) return;
      if (e is http.ClientException) {
        controller.addError(LlmException(LlmErrorKind.network, e.message));
      } else if (e is LlmException) {
        controller.addError(e);
      } else {
        controller.addError(LlmException(LlmErrorKind.server, e.toString()));
      }
      controller.close();
    });

    return controller.stream;
  }

  /// 非流式单次对话（连接测试、AI 创作使用）。
  Future<String> chatOnce({
    required String baseUrl,
    required String apiKey,
    required String model,
    required List<ChatMsg> messages,
    double temperature = 0.7,
  }) async {
    final body = json.encode({
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
    });
    try {
      final res = await _client.post(
        Uri.parse(_endpoint(baseUrl, '/chat/completions')),
        headers: _headers(apiKey),
        body: body,
      );
      if (res.statusCode != 200) {
        throw LlmException(_kindForStatus(res.statusCode), res.body);
      }
      final j = json.decode(res.body) as Map<String, dynamic>;
      return j['choices'][0]['message']['content'] as String;
    } on http.ClientException catch (e) {
      throw LlmException(LlmErrorKind.network, e.message);
    }
  }

  /// 云端 TTS：返回 MP3 字节。
  Future<List<int>> cloudTtsBytes({
    required String baseUrl,
    required String apiKey,
    required String voice,
    required String input,
    String model = 'grok-tts',
  }) async {
    final body = json.encode({
      'model': model,
      'voice': voice,
      'input': input,
    });
    try {
      final res = await _client.post(
        Uri.parse(_endpoint(baseUrl, '/audio/speech')),
        headers: _headers(apiKey),
        body: body,
      );
      if (res.statusCode != 200) {
        throw LlmException(_kindForStatus(res.statusCode), res.body);
      }
      return res.bodyBytes;
    } on http.ClientException catch (e) {
      throw LlmException(LlmErrorKind.network, e.message);
    }
  }

  void dispose() => _client.close();
}
