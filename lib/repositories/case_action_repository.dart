import 'package:cloud_functions/cloud_functions.dart';

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
}
