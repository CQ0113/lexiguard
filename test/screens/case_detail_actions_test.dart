import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/case_model.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/repositories/case_action_repository.dart';
import 'package:lei_guard/repositories/connection_request_repository.dart';
import 'package:lei_guard/screens/shared/case_detail_screen.dart';

class _FakeCaseActionHandler implements CaseActionHandler {
  final List<String> recommendationCaseIds = [];
  final List<bool> recommendationForceRefreshValues = [];

  @override
  Future<void> withdrawCase({required String caseId}) async {}

  @override
  Future<void> closeCase({required String caseId, String? reason}) async {}

  @override
  Future<void> recommendLawyers({
    required String caseId,
    bool forceRefresh = false,
  }) async {
    recommendationCaseIds.add(caseId);
    recommendationForceRefreshValues.add(forceRefresh);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('client sees withdraw action for pending case', (tester) async {
    final repo = ConnectionRequestRepository(
      firestore: FakeFirebaseFirestore(),
    );
    const client = UserModel(
      id: 'client_1',
      name: 'Client A',
      email: 'client@example.com',
      phone: '+600000000',
      role: UserRole.client,
    );

    final pendingCase = CaseModel(
      id: 'case_1',
      clientId: client.id,
      title: 'Pending Case',
      description: 'Pending case description.',
      category: CaseCategory.family,
      status: CaseStatus.pending,
      urgency: CaseUrgency.low,
      createdAt: DateTime.utc(2026, 5, 1),
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: pendingCase,
          viewer: client,
          repository: repo,
          actionHandler: _FakeCaseActionHandler(),
          subscribeToLiveUpdates: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Withdraw case'), findsOneWidget);
    expect(find.text('Close case'), findsNothing);
  });

  testWidgets('client sees close action for active case', (tester) async {
    final repo = ConnectionRequestRepository(
      firestore: FakeFirebaseFirestore(),
    );
    const client = UserModel(
      id: 'client_2',
      name: 'Client B',
      email: 'clientb@example.com',
      phone: '+600000001',
      role: UserRole.client,
    );

    final activeCase = CaseModel(
      id: 'case_2',
      clientId: client.id,
      lawyerId: 'lawyer_1',
      title: 'Active Case',
      description: 'Active case description.',
      category: CaseCategory.property,
      status: CaseStatus.active,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.utc(2026, 5, 2),
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: activeCase,
          viewer: client,
          repository: repo,
          actionHandler: _FakeCaseActionHandler(),
          subscribeToLiveUpdates: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Close case'), findsOneWidget);
    expect(find.text('Withdraw case'), findsNothing);
  });

  testWidgets('client auto-triggers recommendations once for eligible case', (
    tester,
  ) async {
    final repo = ConnectionRequestRepository(
      firestore: FakeFirebaseFirestore(),
    );
    const client = UserModel(
      id: 'client_3',
      name: 'Client C',
      email: 'clientc@example.com',
      phone: '+600000002',
      role: UserRole.client,
    );
    final actionHandler = _FakeCaseActionHandler();

    final pendingCase = CaseModel(
      id: 'case_3',
      clientId: client.id,
      title: 'Needs recommendations',
      description: 'Pending case description.',
      category: CaseCategory.commercial,
      status: CaseStatus.pending,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.utc(2026, 5, 3),
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: pendingCase,
          viewer: client,
          repository: repo,
          actionHandler: actionHandler,
          subscribeToLiveUpdates: false,
        ),
      ),
    );
    await tester.pump();

    expect(actionHandler.recommendationCaseIds, ['case_3']);

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: pendingCase,
          viewer: client,
          repository: repo,
          actionHandler: actionHandler,
          subscribeToLiveUpdates: false,
        ),
      ),
    );
    await tester.pump();

    expect(actionHandler.recommendationCaseIds, ['case_3']);
  });

  testWidgets('client does not auto-trigger while recommendations generate', (
    tester,
  ) async {
    final repo = ConnectionRequestRepository(
      firestore: FakeFirebaseFirestore(),
    );
    const client = UserModel(
      id: 'client_4',
      name: 'Client D',
      email: 'clientd@example.com',
      phone: '+600000003',
      role: UserRole.client,
    );
    final actionHandler = _FakeCaseActionHandler();

    final pendingCase = CaseModel(
      id: 'case_4',
      clientId: client.id,
      title: 'Generating recommendations',
      description: 'Pending case description.',
      category: CaseCategory.family,
      status: CaseStatus.pending,
      urgency: CaseUrgency.low,
      createdAt: DateTime.utc(2026, 5, 4),
      recommendationStatus: 'generating',
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: pendingCase,
          viewer: client,
          repository: repo,
          actionHandler: actionHandler,
          subscribeToLiveUpdates: false,
        ),
      ),
    );
    await tester.pump();

    expect(actionHandler.recommendationCaseIds, isEmpty);
    expect(find.text('Finding suitable lawyers...'), findsOneWidget);
  });

  testWidgets('client does not overwrite completed recommendations', (
    tester,
  ) async {
    final repo = ConnectionRequestRepository(
      firestore: FakeFirebaseFirestore(),
    );
    const client = UserModel(
      id: 'client_5',
      name: 'Client E',
      email: 'cliente@example.com',
      phone: '+600000004',
      role: UserRole.client,
    );
    final actionHandler = _FakeCaseActionHandler();

    final pendingCase = CaseModel(
      id: 'case_5',
      clientId: client.id,
      title: 'Completed recommendations',
      description: 'Pending case description.',
      category: CaseCategory.property,
      status: CaseStatus.pending,
      urgency: CaseUrgency.high,
      createdAt: DateTime.utc(2026, 5, 5),
      recommendationStatus: 'completed',
      lawyerRecommendations: const [
        LawyerRecommendation(
          lawyerId: 'lawyer_1',
          lawyerName: 'Lawyer One',
          specialization: 'Property',
          practiceState: 'Selangor',
          practiceCity: 'Shah Alam',
          yearsExperience: 8,
          languages: ['English'],
          hourlyRate: 250,
          matchPercentage: 92,
          matchReason: 'Matches the property case category.',
        ),
      ],
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: pendingCase,
          viewer: client,
          repository: repo,
          actionHandler: actionHandler,
          subscribeToLiveUpdates: false,
        ),
      ),
    );
    await tester.pump();

    expect(actionHandler.recommendationCaseIds, isEmpty);
    expect(find.text('Lawyer One'), findsOneWidget);
  });

  testWidgets('client can force-refresh completed recommendations', (
    tester,
  ) async {
    final repo = ConnectionRequestRepository(
      firestore: FakeFirebaseFirestore(),
    );
    const client = UserModel(
      id: 'client_6',
      name: 'Client F',
      email: 'clientf@example.com',
      phone: '+600000005',
      role: UserRole.client,
    );
    final actionHandler = _FakeCaseActionHandler();

    final pendingCase = CaseModel(
      id: 'case_6',
      clientId: client.id,
      title: 'Refresh recommendations',
      description: 'Pending case description.',
      category: CaseCategory.property,
      status: CaseStatus.pending,
      urgency: CaseUrgency.high,
      createdAt: DateTime.utc(2026, 5, 6),
      recommendationStatus: 'completed',
      lawyerRecommendations: const [
        LawyerRecommendation(
          lawyerId: 'lawyer_1',
          lawyerName: 'Lawyer One',
          specialization: 'Property',
          practiceState: 'Selangor',
          practiceCity: 'Shah Alam',
          yearsExperience: 8,
          languages: ['English'],
          hourlyRate: 250,
          matchPercentage: 92,
          matchReason: 'Matches the property case category.',
        ),
      ],
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: pendingCase,
          viewer: client,
          repository: repo,
          actionHandler: actionHandler,
          subscribeToLiveUpdates: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final refreshButton = find.text('Refresh');
    expect(refreshButton, findsOneWidget);

    await tester.ensureVisible(refreshButton);
    await tester.pumpAndSettle();
    await tester.tap(refreshButton);
    await tester.pump();

    expect(actionHandler.recommendationCaseIds, ['case_6']);
    expect(actionHandler.recommendationForceRefreshValues, [true]);
  });
}
