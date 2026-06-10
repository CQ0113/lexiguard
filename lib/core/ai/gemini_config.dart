import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiConfig {
  const GeminiConfig({
    required this.apiKey,
    this.model = 'gemini-2.5-flash',
    this.apiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  });

  factory GeminiConfig.fromEnvironment() {
    return GeminiConfig(
      apiKey: (dotenv.env['GEMINI_API_KEY'] ?? '').trim(),
      model: _valueOrDefault('GEMINI_MODEL', 'gemini-2.5-flash'),
      apiBaseUrl: _valueOrDefault(
        'GEMINI_API_BASE_URL',
        'https://generativelanguage.googleapis.com/v1beta',
      ),
    );
  }

  final String apiKey;
  final String model;
  final String apiBaseUrl;

  bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.contains('YOUR_') && model.trim().isNotEmpty;

  Uri get generateContentUri {
    final normalizedBaseUrl = apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final encodedModel = Uri.encodeComponent(model.trim());
    return Uri.parse('$normalizedBaseUrl/models/$encodedModel:generateContent');
  }

  void validate() {
    if (!isConfigured) {
      throw StateError(
        'Gemini is not configured. Set GEMINI_API_KEY in .env first.',
      );
    }
  }

  static String _valueOrDefault(String key, String defaultValue) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? defaultValue : value;
  }
}
