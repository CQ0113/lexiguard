import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/lexibot_response.dart';
import 'package:lei_guard/screens/client/lexibot_chat_screen.dart';
import 'package:lei_guard/services/lexibot_service.dart';

class _FakeLexiBotClient implements LexiBotClient {
  _FakeLexiBotClient({this.handler});

  final Future<LexiBotResponse> Function(String question)? handler;
  String? lastQuestion;

  @override
  Future<LexiBotResponse> askQuestion({
    required String question,
    String? conversationId,
  }) async {
    lastQuestion = question;
    if (handler != null) return handler!(question);
    return groundedResponse;
  }
}

const groundedResponse = LexiBotResponse(
  status: 'answered',
  scopeStatus: 'in_scope',
  riskLevel: 'low',
  auditId: 'audit-id',
  groundingChunkCount: 2,
  answer: LexiBotAnswer(
    shortAnswer: 'Keep your receipts and tenancy agreement.',
    whatTheSourceSays: 'Rent distress is governed by the Act.',
    whatThisMeans: 'The landlord must follow legal process.',
    evidenceToKeep: ['Rental receipts'],
    whatYouCanDoNext: ['Review your tenancy agreement'],
    sourcesUsed: ['Distress Act 1951'],
    needALawyer: 'Consider legal help if a dispute continues.',
  ),
  citations: [
    LexiBotCitation(
      title: 'Distress Act 1951',
      sourceId: 'distress_act_1951',
      sourceUrl: 'https://example.test/distress.pdf',
    ),
  ],
);

const urgentResponse = LexiBotResponse(
  status: 'urgent_escalation',
  scopeStatus: 'urgent_escalation',
  riskLevel: 'high',
  auditId: 'audit-urgent',
  groundingChunkCount: 0,
  answer: LexiBotAnswer(
    shortAnswer: 'This situation may need urgent legal help.',
    whatTheSourceSays: '',
    whatThisMeans: 'A lockout may require prompt action.',
    evidenceToKeep: [],
    whatYouCanDoNext: ['Contact a Malaysian lawyer promptly.'],
    sourcesUsed: [],
    needALawyer: 'Yes.',
  ),
  citations: [],
);

const outOfScopeResponse = LexiBotResponse(
  status: 'out_of_scope',
  scopeStatus: 'out_of_scope',
  riskLevel: 'high',
  auditId: 'audit-scope',
  groundingChunkCount: 0,
  answer: LexiBotAnswer(
    shortAnswer: 'LexiBot cannot answer this within its tenancy-law scope.',
    whatTheSourceSays: '',
    whatThisMeans: 'This MVP covers residential tenancy only.',
    evidenceToKeep: [],
    whatYouCanDoNext: ['Speak with a qualified Malaysian lawyer.'],
    sourcesUsed: [],
    needALawyer: 'Yes.',
  ),
  citations: [],
);

const malayResponse = LexiBotResponse(
  status: 'answered',
  scopeStatus: 'in_scope',
  riskLevel: 'low',
  responseLanguage: 'ms',
  auditId: 'audit-ms',
  groundingChunkCount: 1,
  answer: LexiBotAnswer(
    shortAnswer: 'Simpan perjanjian sewa dan resit.',
    whatTheSourceSays: 'Sumber yang diluluskan telah dirujuk.',
    whatThisMeans: 'Hak anda bergantung pada perjanjian.',
    evidenceToKeep: ['Perjanjian sewa'],
    whatYouCanDoNext: ['Simpan rekod pembayaran'],
    sourcesUsed: ['Contracts Act 1950'],
    needALawyer: 'Pertimbangkan peguam jika pertikaian berterusan.',
  ),
  citations: [],
);

const chineseResponse = LexiBotResponse(
  status: 'urgent_escalation',
  scopeStatus: 'urgent_escalation',
  riskLevel: 'high',
  responseLanguage: 'zh',
  auditId: 'audit-zh',
  groundingChunkCount: 0,
  answer: LexiBotAnswer(
    shortAnswer: '此情况可能需要尽快向律师寻求帮助。',
    whatTheSourceSays: '',
    whatThisMeans: '此问题可能涉及紧急风险。',
    evidenceToKeep: [],
    whatYouCanDoNext: ['请尽快联系律师。'],
    sourcesUsed: [],
    needALawyer: '是。',
  ),
  citations: [],
);

Widget wrap(LexiBotClient client, {VoidCallback? onRequestLawyer}) {
  return MaterialApp(
    home: Scaffold(
      body: LexiBotChatScreen(client: client, onRequestLawyer: onRequestLawyer),
    ),
  );
}

Future<void> submitQuestion(WidgetTester tester, String question) async {
  await tester.enterText(
    find.byKey(const Key('lexibot-question-field')),
    question,
  );
  await tester.tap(find.byKey(const Key('lexibot-send-button')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('submits a question and renders grounded answer sections', (
    tester,
  ) async {
    final client = _FakeLexiBotClient();
    await tester.pumpWidget(wrap(client));

    await submitQuestion(tester, 'Can my landlord take my things for rent?');
    await tester.pumpAndSettle();

    expect(client.lastQuestion, 'Can my landlord take my things for rent?');
    expect(find.text('Short Answer'), findsOneWidget);
    expect(find.text('What the Source Says'), findsOneWidget);
    expect(find.text('What This Means'), findsOneWidget);
    expect(find.text('Evidence to Keep'), findsOneWidget);
    expect(find.text('What You Can Do Next'), findsOneWidget);
    expect(find.text('Sources Used'), findsOneWidget);
    expect(find.text('Distress Act 1951'), findsOneWidget);
    expect(find.text('Open official source'), findsOneWidget);
    expect(find.text('Need a Lawyer?'), findsOneWidget);
  });

  testWidgets('renders urgent escalation and routes to lawyer support', (
    tester,
  ) async {
    var requestedLawyer = false;
    final client = _FakeLexiBotClient(handler: (_) async => urgentResponse);
    await tester.pumpWidget(
      wrap(client, onRequestLawyer: () => requestedLawyer = true),
    );

    await submitQuestion(tester, 'My landlord changed the locks today.');
    await tester.pumpAndSettle();

    expect(find.text('Review needed'), findsOneWidget);
    expect(
      find.text('This situation may need urgent legal help.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Post a case for lawyer support'));
    expect(requestedLawyer, isTrue);
  });

  testWidgets('shows loading state while waiting for the backend', (
    tester,
  ) async {
    final completer = Completer<LexiBotResponse>();
    final client = _FakeLexiBotClient(handler: (_) => completer.future);
    await tester.pumpWidget(wrap(client));

    await submitQuestion(tester, 'Can my landlord retain my deposit?');
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(groundedResponse);
    await tester.pumpAndSettle();
    expect(find.text('Grounded'), findsOneWidget);
  });

  testWidgets('renders an out-of-scope refusal as review needed', (
    tester,
  ) async {
    final client = _FakeLexiBotClient(handler: (_) async => outOfScopeResponse);
    await tester.pumpWidget(wrap(client));

    await submitQuestion(tester, 'Can you advise on a criminal charge?');
    await tester.pumpAndSettle();

    expect(find.text('Review needed'), findsOneWidget);
    expect(
      find.text('LexiBot cannot answer this within its tenancy-law scope.'),
      findsOneWidget,
    );
  });

  testWidgets('renders Malay answer labels for a Malay response', (
    tester,
  ) async {
    final client = _FakeLexiBotClient(handler: (_) async => malayResponse);
    await tester.pumpWidget(wrap(client));

    await submitQuestion(tester, 'Tuan rumah enggan pulangkan deposit sewa.');
    await tester.pumpAndSettle();

    expect(find.text('Jawapan Ringkas'), findsOneWidget);
    expect(find.text('Langkah Seterusnya'), findsOneWidget);
    expect(find.text('Perlukan Peguam?'), findsOneWidget);
  });

  testWidgets('renders Chinese escalation labels for a Chinese response', (
    tester,
  ) async {
    final client = _FakeLexiBotClient(handler: (_) async => chineseResponse);
    await tester.pumpWidget(wrap(client, onRequestLawyer: () {}));

    await submitQuestion(tester, '房东换锁了。');
    await tester.pumpAndSettle();

    expect(find.text('需要审查'), findsOneWidget);
    expect(find.text('简短回答'), findsOneWidget);
    expect(find.text('提交案件以寻求律师协助'), findsOneWidget);
  });

  testWidgets('shows a safe failure message when the callable fails', (
    tester,
  ) async {
    final client = _FakeLexiBotClient(
      handler: (_) async => throw StateError('network unavailable'),
    );
    await tester.pumpWidget(wrap(client));

    await submitQuestion(tester, 'Can my landlord retain my deposit?');
    await tester.pumpAndSettle();

    expect(
      find.text('LexiBot could not answer right now. Please try again later.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a timeout-specific safe failure message', (tester) async {
    final client = _FakeLexiBotClient(
      handler: (_) async => throw TimeoutException('too slow'),
    );
    await tester.pumpWidget(wrap(client));

    await submitQuestion(tester, 'Can my landlord retain my deposit?');
    await tester.pumpAndSettle();

    expect(
      find.text(
        'LexiBot is taking too long to answer. Please try again later.',
      ),
      findsOneWidget,
    );
  });
}
