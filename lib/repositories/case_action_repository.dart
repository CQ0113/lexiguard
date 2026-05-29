import 'package:cloud_functions/cloud_functions.dart';

import '../core/firebase/firebase_initializer.dart';

abstract class CaseActionHandler {
  Future<void> withdrawCase({required String caseId});
  Future<void> closeCase({required String caseId, String? reason});
}

class CaseActionRepository implements CaseActionHandler {
  CaseActionRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<void> withdrawCase({required String caseId}) async {
    if (!FirebaseInitializer.isReady) {
      throw StateError('Firebase is not configured.');
    }

    final callable = _functions.httpsCallable('withdrawCase');
    await callable.call({'caseId': caseId});
  }

  @override
  Future<void> closeCase({required String caseId, String? reason}) async {
    if (!FirebaseInitializer.isReady) {
      throw StateError('Firebase is not configured.');
    }

    final payload = <String, dynamic>{'caseId': caseId};
    final trimmed = reason?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      payload['reason'] = trimmed;
    }

    final callable = _functions.httpsCallable('closeCase');
    await callable.call(payload);
  }
}
