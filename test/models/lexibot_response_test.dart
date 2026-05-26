import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/lexibot_response.dart';

void main() {
  test('fromMap parses grounded answer response and citations', () {
    final response = LexiBotResponse.fromMap({
      'status': 'answered',
      'scopeStatus': 'in_scope',
      'riskLevel': 'low',
      'groundingChunkCount': 3,
      'auditId': 'audit-1',
      'answer': {
        'shortAnswer': 'A distress action must follow the Act.',
        'whatTheSourceSays': 'The source text.',
        'whatThisMeans': 'It is not self-help.',
        'evidenceToKeep': ['Tenancy agreement'],
        'whatYouCanDoNext': ['Keep rent receipts'],
        'sourcesUsed': ['Distress Act 1951'],
        'needALawyer': 'Consider a lawyer for a dispute.',
      },
      'citations': [
        {
          'title': 'Distress Act 1951',
          'sourceId': 'distress_act_1951',
          'sourceUrl': 'https://example.test/distress.pdf',
        },
      ],
    });

    expect(response.status, 'answered');
    expect(response.needsLawyer, isFalse);
    expect(response.groundingChunkCount, 3);
    expect(response.citations.single.sourceId, 'distress_act_1951');
    expect(response.answer.whatYouCanDoNext.single, 'Keep rent receipts');
  });

  test('escalation response is identified as needing a lawyer', () {
    final response = LexiBotResponse.fromMap({
      'status': 'urgent_escalation',
      'scopeStatus': 'urgent_escalation',
      'riskLevel': 'high',
      'answer': {
        'shortAnswer': 'Seek urgent legal help.',
        'whatTheSourceSays': '',
        'whatThisMeans': 'A lockout may be urgent.',
        'evidenceToKeep': [],
        'whatYouCanDoNext': ['Contact a lawyer.'],
        'sourcesUsed': [],
        'needALawyer': 'Yes.',
      },
      'citations': [],
    });

    expect(response.needsLawyer, isTrue);
  });
}
