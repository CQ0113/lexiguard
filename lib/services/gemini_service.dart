import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/ai/gemini_config.dart';

class GeminiService {
  GeminiService({GeminiConfig? config, http.Client? client})
    : _config = config ?? GeminiConfig.fromEnvironment(),
      _client = client ?? http.Client();

  final GeminiConfig _config;
  final http.Client _client;

  Future<String> testConnection() {
    return generateText(prompt: 'Reply with OK.');
  }

  Future<String> generateText({
    required String prompt,
    String? systemInstruction,
  }) async {
    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      throw ArgumentError.value(prompt, 'prompt', 'Prompt cannot be empty.');
    }

    _config.validate();

    final body = <String, Object>{
      'contents': [
        {
          'parts': [
            {'text': trimmedPrompt},
          ],
        },
      ],
    };

    final trimmedInstruction = systemInstruction?.trim();
    if (trimmedInstruction != null && trimmedInstruction.isNotEmpty) {
      body['system_instruction'] = {
        'parts': [
          {'text': trimmedInstruction},
        ],
      };
    }

    final response = await _client.post(
      _config.generateContentUri,
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': _config.apiKey,
      },
      body: jsonEncode(body),
    );

    final responseBody = _decodeBody(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _apiErrorMessage(responseBody);
      throw GeminiException(
        message == null
            ? 'Gemini request failed with status ${response.statusCode}.'
            : 'Gemini request failed: $message',
        statusCode: response.statusCode,
      );
    }

    final text = _responseText(responseBody);
    if (text == null || text.trim().isEmpty) {
      throw const GeminiException('Gemini returned no text response.');
    }

    return text.trim();
  }

  void close() {
    _client.close();
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static String? _apiErrorMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is! Map<String, dynamic>) return null;
    final message = error['message'];
    return message is String && message.trim().isNotEmpty
        ? message.trim()
        : null;
  }

  static String? _responseText(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final firstCandidate = candidates.first;
    if (firstCandidate is! Map<String, dynamic>) return null;
    final content = firstCandidate['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'];
    if (parts is! List) return null;

    final textParts = parts
        .whereType<Map<String, dynamic>>()
        .map((part) => part['text'])
        .whereType<String>();
    return textParts.join();
  }
}

class GeminiException implements Exception {
  const GeminiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
