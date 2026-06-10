import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lei_guard/core/ai/gemini_config.dart';
import 'package:lei_guard/services/gemini_service.dart';

void main() {
  const config = GeminiConfig(apiKey: 'configured-api-key');

  test(
    'generateText sends a Gemini 2.5 Flash request and extracts text',
    () async {
      final service = GeminiService(
        config: config,
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://generativelanguage.googleapis.com/v1beta/'
            'models/gemini-2.5-flash:generateContent',
          );
          expect(request.headers['x-goog-api-key'], 'configured-api-key');

          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['contents'][0]['parts'][0]['text'], 'Hello Gemini');
          expect(body['system_instruction']['parts'][0]['text'], 'Be concise.');

          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Connected'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final text = await service.generateText(
        prompt: 'Hello Gemini',
        systemInstruction: 'Be concise.',
      );

      expect(text, 'Connected');
      service.close();
    },
  );

  test('generateText reports API errors with the response message', () async {
    final service = GeminiService(
      config: config,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'API key not valid.'},
          }),
          400,
        ),
      ),
    );

    expect(
      () => service.generateText(prompt: 'Hello'),
      throwsA(
        isA<GeminiException>()
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.message,
              'message',
              'Gemini request failed: API key not valid.',
            ),
      ),
    );
    service.close();
  });

  test('generateText requires a configured API key before requesting', () {
    final service = GeminiService(
      config: const GeminiConfig(apiKey: 'YOUR_GEMINI_API_KEY'),
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    expect(
      () => service.generateText(prompt: 'Hello'),
      throwsA(isA<StateError>()),
    );
    service.close();
  });
}
