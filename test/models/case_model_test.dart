import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/case_model.dart';

void main() {
  test('fromMap parses withdrawn status and fields', () {
    final map = {
      'id': 'case_1',
      'clientId': 'client_1',
      'title': 'Withdrawn Case',
      'description': 'Client withdrew before accepting a lawyer.',
      'category': 'family',
      'status': 'withdrawn',
      'urgency': 'low',
      'progressPercent': 0,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 1)),
      'withdrawnAt': Timestamp.fromDate(DateTime.utc(2026, 5, 2)),
      'withdrawnBy': 'client_1',
      'interestedLawyerIds': <String>[],
    };

    final model = CaseModel.fromMap(map);

    expect(model.status, CaseStatus.withdrawn);
    expect(model.withdrawnBy, 'client_1');
    expect(model.withdrawnAt?.toUtc(), DateTime.utc(2026, 5, 2));
  });

  test('toFirestore writes closure fields when provided', () {
    final model = CaseModel(
      id: 'case_2',
      clientId: 'client_2',
      lawyerId: 'lawyer_1',
      title: 'Closed Case',
      description: 'Resolved dispute.',
      category: CaseCategory.property,
      status: CaseStatus.closed,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.utc(2026, 5, 3),
      closedAt: DateTime.utc(2026, 5, 6),
      closedBy: 'client_2',
      closeReason: 'Resolved amicably.',
    );

    final data = model.toFirestore();

    expect(data['closedAt'], isA<Timestamp>());
    expect(data['closedBy'], 'client_2');
    expect(data['closeReason'], 'Resolved amicably.');
  });

  test('lawyer recommendation accepts backend matchScore schema', () {
    final recommendation = LawyerRecommendation.fromMap({
      'lawyerId': 'lawyer_1',
      'lawyerName': 'Aina Legal',
      'specialization': 'Property',
      'practiceState': 'Johor',
      'practiceCity': 'Johor Bahru',
      'yearsExperience': 7,
      'languages': ['English', 'Malay'],
      'hourlyRate': 180,
      'matchScore': 87,
      'matchReasons': [
        'Practice area matches the property case.',
        'Location matches Johor Bahru.',
      ],
    });

    expect(recommendation.matchPercentage, 87);
    expect(
      recommendation.matchReason,
      'Practice area matches the property case. Location matches Johor Bahru.',
    );
  });
}
