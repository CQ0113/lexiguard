import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../services/lawyer_recommendation_service.dart';

abstract class CaseActionHandler {
  Future<void> withdrawCase({required String caseId});
  Future<void> closeCase({required String caseId, String? reason});
  Future<void> recommendLawyers({
    required String caseId,
    bool forceRefresh = false,
  });
}

class CaseActionRepository implements CaseActionHandler {
  CaseActionRepository({
    FirebaseFunctions? functions,
    LawyerRecommendationService? recommendationService,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _recommendationService =
           recommendationService ?? LawyerRecommendationService();

  final FirebaseFunctions _functions;
  final LawyerRecommendationService _recommendationService;

  @override
  Future<void> withdrawCase({required String caseId}) async {
    final callable = _functions.httpsCallable('withdrawCase');
    await callable.call({'caseId': caseId});
  }

  @override
  Future<void> closeCase({required String caseId, String? reason}) async {
    final payload = <String, dynamic>{'caseId': caseId};
    final trimmed = reason?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      payload['reason'] = trimmed;
    }

    final callable = _functions.httpsCallable('closeCase');
    await callable.call(payload);
  }

  @override
  Future<void> recommendLawyers({
    required String caseId,
    bool forceRefresh = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('recommendLawyersForCase');
      await callable
          .call({'caseId': caseId, if (forceRefresh) 'forceRefresh': true})
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () =>
                throw TimeoutException('Lawyer recommendation timed out.'),
          );
    } catch (e) {
      debugPrint(
        'Cloud function recommendLawyersForCase failed: $e. Falling back to local scoring service...',
      );
      await _recommendationService.recommendLawyersForCase(caseId);
    }
  }
}
