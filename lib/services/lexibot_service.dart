import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/lexibot_response.dart';

abstract interface class LexiBotClient {
  Future<LexiBotResponse> askQuestion({
    required String question,
    String? conversationId,
  });
}

class LexiBotService implements LexiBotClient {
  LexiBotService({FirebaseFunctions? functions}) : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ?? FirebaseFunctions.instance;

  @override
  Future<LexiBotResponse> askQuestion({
    required String question,
    String? conversationId,
  }) async {
    final trimmedQuestion = question.trim();
    if (trimmedQuestion.isEmpty) {
      throw ArgumentError.value(question, 'question', 'Question is required.');
    }

    final result = await _resolvedFunctions
        .httpsCallable('askLexiBot')
        .call({
          'question': trimmedQuestion,
          if (conversationId != null && conversationId.isNotEmpty)
            'conversationId': conversationId,
        })
        .timeout(
          const Duration(seconds: 180),
          onTimeout: () => throw TimeoutException(
            'LexiBot did not answer within the client timeout.',
          ),
        );

    final data = result.data;
    if (data is! Map) {
      throw const FormatException('LexiBot returned an invalid response.');
    }
    return LexiBotResponse.fromMap(Map<String, dynamic>.from(data));
  }
}
