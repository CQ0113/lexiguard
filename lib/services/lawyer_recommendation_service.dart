import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../core/firebase/firebase_initializer.dart';
import '../models/case_model.dart';

class LawyerRecommendationService {
  LawyerRecommendationService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _httpClient = httpClient ?? http.Client();

  static const String modelName = 'gemini-2.5-flash-direct-flutter-prototype';
  static const String _geminiModel = 'gemini-2.5-flash';

  final FirebaseFirestore _firestore;
  final http.Client _httpClient;

  Future<void> recommendLawyersForCase(String caseId) async {
    if (!FirebaseInitializer.isReady) {
      throw StateError('Firebase is not configured.');
    }

    final caseRef = _firestore.collection('cases').doc(caseId);

    await caseRef.update({
      'recommendationStatus': 'generating',
      'recommendationModel': modelName,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      final caseSnap = await caseRef.get();
      if (!caseSnap.exists) {
        throw StateError('Case not found.');
      }

      final caseModel = CaseModel.fromFirestore(caseSnap);
      final lawyers = await _readLawyerCandidates();

      if (lawyers.isEmpty) {
        await _saveNotEnoughLawyers(caseRef);
        return;
      }

      final caseDetails = {
        'caseId': caseModel.id,
        'title': caseModel.title,
        'description': caseModel.description,
        'category': caseModel.category.name,
        'location': caseModel.location ?? '',
        'budgetRange': caseModel.budgetRange ?? '',
        'urgency': caseModel.urgency.name,
      };

      final geminiRecommendations = await _callGemini(
        caseDetails: caseDetails,
        lawyers: lawyers,
      );
      final recommendations = _mapToTrustedRecommendations(
        geminiRecommendations: geminiRecommendations,
        lawyers: lawyers,
      );

      if (recommendations.isEmpty) {
        await _saveNotEnoughLawyers(caseRef);
        return;
      }

      await caseRef.update({
        'lawyerRecommendations': recommendations,
        'recommendationStatus': 'completed',
        'recommendationGeneratedAt': FieldValue.serverTimestamp(),
        'recommendationModel': modelName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      await caseRef.update({
        'recommendationStatus': 'failed',
        'recommendationGeneratedAt': FieldValue.serverTimestamp(),
        'recommendationModel': modelName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _readLawyerCandidates() async {
    final snap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'lawyer')
        .where('verificationStatus', isEqualTo: 'auto_verified')
        .get();

    final candidates = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'lawyerId': doc.id,
        'name':
            data['name']?.toString() ??
            data['legalFullName']?.toString() ??
            'Anonymous Lawyer',
        'specialization':
            data['specialization']?.toString() ??
            data['practiceArea']?.toString() ??
            data['primaryPracticeArea']?.toString() ??
            'General Practice',
        'yearsExperience': (data['yearsExperience'] as num?)?.toInt() ?? 0,
        'practiceState': data['practiceState']?.toString() ?? '',
        'practiceCity': data['practiceCity']?.toString() ?? '',
        'languages': List<String>.from(data['languages'] as List? ?? []),
        'hourlyRate': (data['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();

    return candidates;
  }

  Future<List<Map<String, dynamic>>> _callGemini({
    required Map<String, dynamic> caseDetails,
    required List<Map<String, dynamic>> lawyers,
  }) async {
    // Prototype/demo only: this exposes the API key in the Flutter app bundle.
    // Move Gemini calls back to backend Cloud Functions before production.
    final apiKey = dotenv.env['GEMINI_API_KEY']?.trim();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('GEMINI_API_KEY is missing in .env.');
    }

    final prompt =
        '''
You are matching a legal case to suitable lawyers.
Use only the provided case details and lawyer details.
Return valid JSON only with exactly this shape:
{
  "recommendations": [
    {
      "lawyerId": "abc123",
      "matchPercentage": 88,
      "matchReason": "Short reason explaining what matches the case."
    }
  ]
}
Rules:
- matchPercentage must be 0 to 100.
- Do not invent lawyer IDs or lawyer details.
- Return exactly the top 3 lawyers when at least 3 lawyers are available. If fewer than 3 lawyers are available, return all available lawyers.
- Sort from highest to lowest matchPercentage.
- matchReason must be one short sentence based only on the provided case and lawyer details.
- Do not include concerns or extra fields.

Case:
${jsonEncode(caseDetails)}

Lawyers:
${jsonEncode(lawyers)}
''';

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_geminiModel:generateContent',
      {'key': apiKey},
    );

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Gemini API failed with ${response.statusCode}: ${response.body}',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final text =
        payload['candidates']?[0]?['content']?['parts']?[0]?['text']
            ?.toString() ??
        '';
    final parsed = jsonDecode(_cleanJsonText(text)) as Map<String, dynamic>;
    final recommendations = parsed['recommendations'];
    if (recommendations is! List) {
      throw StateError('Gemini response missing recommendations array.');
    }

    return recommendations
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> _mapToTrustedRecommendations({
    required List<Map<String, dynamic>> geminiRecommendations,
    required List<Map<String, dynamic>> lawyers,
  }) {
    final lawyersById = {
      for (final lawyer in lawyers) lawyer['lawyerId']?.toString(): lawyer,
    };
    final seen = <String>{};
    final output = <Map<String, dynamic>>[];

    for (final recommendation in geminiRecommendations) {
      if (output.length >= 3) break;

      final lawyerId = recommendation['lawyerId']?.toString();
      if (lawyerId == null || lawyerId.isEmpty || seen.contains(lawyerId)) {
        continue;
      }

      final lawyer = lawyersById[lawyerId];
      if (lawyer == null) continue;

      final percentage = (recommendation['matchPercentage'] as num?)
          ?.round()
          .clamp(0, 100);
      if (percentage == null) continue;

      seen.add(lawyerId);
      output.add({
        'lawyerId': lawyerId,
        'lawyerName': lawyer['name']?.toString() ?? 'Anonymous Lawyer',
        'specialization':
            lawyer['specialization']?.toString() ?? 'General Practice',
        'practiceState': lawyer['practiceState']?.toString() ?? '',
        'practiceCity': lawyer['practiceCity']?.toString() ?? '',
        'yearsExperience': (lawyer['yearsExperience'] as num?)?.toInt() ?? 0,
        'languages': List<String>.from(lawyer['languages'] as List? ?? []),
        'hourlyRate': (lawyer['hourlyRate'] as num?)?.toDouble() ?? 0.0,
        'matchPercentage': percentage,
        'matchReason': recommendation['matchReason']?.toString() ?? '',
      });
    }

    output.sort((a, b) {
      final aPercentage = (a['matchPercentage'] as num?)?.toInt() ?? 0;
      final bPercentage = (b['matchPercentage'] as num?)?.toInt() ?? 0;
      return bPercentage.compareTo(aPercentage);
    });

    return output;
  }

  Future<void> _saveNotEnoughLawyers(
    DocumentReference<Map<String, dynamic>> caseRef,
  ) {
    return caseRef.update({
      'lawyerRecommendations': <Map<String, dynamic>>[],
      'recommendationStatus': 'not_enough_lawyers',
      'recommendationGeneratedAt': FieldValue.serverTimestamp(),
      'recommendationModel': modelName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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
