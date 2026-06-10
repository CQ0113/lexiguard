import 'package:cloud_functions/cloud_functions.dart';

import '../core/firebase/firebase_initializer.dart';
import '../services/lawyer_recommendation_service.dart';

abstract class CaseActionHandler {
  Future<void> withdrawCase({required String caseId});
  Future<void> closeCase({required String caseId, String? reason});
  Future<void> recommendLawyers({required String caseId});
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
  Future<void> recommendLawyers({required String caseId}) async {
    await _recommendationService.recommendLawyersForCase(caseId);
  }
}
