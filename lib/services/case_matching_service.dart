import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/case_model.dart';
import '../models/user_model.dart';

class MatchResult {
  final String caseId;
  final int matchPercentage;
  final String matchReason;

  const MatchResult({
    required this.caseId,
    required this.matchPercentage,
    required this.matchReason,
  });

  factory MatchResult.fromMap(Map<String, dynamic> map) {
    return MatchResult(
      caseId: map['caseId']?.toString() ?? '',
      matchPercentage: (map['matchPercentage'] as num?)?.toInt().clamp(0, 100) ?? 0,
      matchReason: map['matchReason']?.toString() ?? '',
    );
  }
}

class CaseMatchingService {
  CaseMatchingService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  static const String _geminiModel = 'gemini-2.5-flash';

  Future<List<MatchResult>> matchCasesToLawyer({
    required UserModel lawyer,
    required List<CaseModel> cases,
  }) async {
    if (cases.isEmpty) return const [];

    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      // Return default empty/unmatched results in test/unconfigured environments
      return cases.map((c) => MatchResult(
        caseId: c.id,
        matchPercentage: 0,
        matchReason: 'Gemini matching not configured.',
      )).toList();
    }

    final lawyerDetails = {
      'specialization': lawyer.specialization ?? '',
      'practiceState': lawyer.practiceState ?? '',
      'practiceCity': lawyer.practiceCity ?? '',
      'hourlyRate': lawyer.hourlyRate ?? 0.0,
      'yearsExperience': lawyer.yearsExperience ?? 0,
      'languages': lawyer.languages,
    };

    final casesDetails = cases.map((c) => {
      'caseId': c.id,
      'title': c.title,
      'description': c.description,
      'category': c.categoryLabel,
      'location': c.location ?? '',
      'budgetRange': c.budgetRange ?? '',
      'urgency': c.urgencyLabel,
    }).toList();

    final prompt = '''
You are matching a lawyer profile to a list of legal cases to find the best fits.
Use only the provided lawyer details and cases.
Compare the location, category, budget, specialization, and other attributes of each case against the lawyer profile.
Calculate a match percentage (0 to 100) and provide a short one-sentence explanation of the match for each case.

Return valid JSON only, with exactly this shape:
{
  "matches": [
    {
      "caseId": "case_id_here",
      "matchPercentage": 85,
      "matchReason": "This case matches your specialization in Property Law and is located in your practice state of Selangor."
    }
  ]
}

Rules:
- matchPercentage must be an integer between 0 and 100.
- Do not invent case IDs or lawyer details.
- Return a match for every provided case.
- matchReason must be a short, professional sentence (in English) explaining the match or lack thereof. Do not include any greeting or conversational filler outside the JSON.

Lawyer Profile:
${jsonEncode(lawyerDetails)}

Cases to Match:
${jsonEncode(casesDetails)}
''';

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_geminiModel:generateContent',
      {'key': apiKey},
    );

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });

    // Retry with exponential backoff for transient errors (503, 429, etc.)
    const maxAttempts = 3;
    http.Response? response;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) break;

      // Retry on 503 (overloaded) or 429 (rate limited), but not other errors
      if ((response.statusCode == 503 || response.statusCode == 429) &&
          attempt < maxAttempts) {
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
        continue;
      }

      throw StateError(
        'Gemini API failed with ${response.statusCode}: ${response.body}',
      );
    }

    final payload = jsonDecode(response!.body) as Map<String, dynamic>;
    final text =
        payload['candidates']?[0]?['content']?['parts']?[0]?['text']
            ?.toString() ??
        '';
    
    final parsed = jsonDecode(_cleanJsonText(text)) as Map<String, dynamic>;
    final matches = parsed['matches'];
    if (matches is! List) {
      throw StateError('Gemini response missing matches array.');
    }

    return matches.map((item) {
      final map = Map<String, dynamic>.from(item);
      return MatchResult.fromMap(map);
    }).toList();
  }

  String _cleanJsonText(String value) {
    var text = value.trim();
    if (text.startsWith('```json')) {
      text = text.substring(7).trim();
    } else if (text.startsWith('```')) {
      text = text.substring(3).trim();
    }
    if (text.endsWith('```')) {
      text = text.substring(0, text.length - 3).trim();
    }
    return text;
  }
}
