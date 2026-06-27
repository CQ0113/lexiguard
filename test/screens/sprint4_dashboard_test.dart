import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/case_model.dart';
import 'package:lei_guard/repositories/case_repository.dart';

import '../helpers/dashboard_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Client Dashboard: Recent Activity uses Firestore data', (
    tester,
  ) async {
    final db = DashboardTestHarness.createFakeDb();
    final client = DashboardTestHarness.client;

    final caseModel = CaseModel(
      id: 'case_recent_activity',
      clientId: client.id,
      title: 'Dynamic Tenancy Case',
      description: 'Recent activity test case.',
      category: CaseCategory.property,
      status: CaseStatus.pending,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
    );

    await db
        .collection(CaseRepository.collectionName)
        .doc(caseModel.id)
        .set(caseModel.toFirestore());

    await tester.pumpWidget(
      DashboardTestHarness.wrapClient(user: client, firestore: db),
    );
    await tester.pumpAndSettle();

    expect(find.text('Case posted'), findsOneWidget);
    expect(find.text('Dynamic Tenancy Case • Property'), findsOneWidget);
    expect(find.text('Contract reviewed by AI'), findsNothing);
    expect(find.text('New message from Pn. Aishah'), findsNothing);
    expect(find.text('Document shared'), findsNothing);
  });

  testWidgets(
    'Client Dashboard: tapping View All activities opens live history',
    (tester) async {
      final db = DashboardTestHarness.createFakeDb();
      final client = DashboardTestHarness.client;

      final caseModel = CaseModel(
        id: 'case_activity_sheet',
        clientId: client.id,
        title: 'Activity Sheet Case',
        description: 'Recent activity sheet test case.',
        category: CaseCategory.family,
        status: CaseStatus.pending,
        urgency: CaseUrgency.low,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await db
          .collection(CaseRepository.collectionName)
          .doc(caseModel.id)
          .set(caseModel.toFirestore());

      await tester.pumpWidget(
        DashboardTestHarness.wrapClient(user: client, firestore: db),
      );
      await tester.pumpAndSettle();

      final viewAllActivities = find.text('View All').first;
      expect(viewAllActivities, findsOneWidget);
      await tester.ensureVisible(viewAllActivities);
      await tester.pumpAndSettle();

      await tester.tap(viewAllActivities);
      await tester.pumpAndSettle();

      expect(find.text('Recent Activity'), findsNWidgets(2));
      expect(find.text('Activity Sheet Case • Family'), findsNWidgets(2));
    },
  );

  testWidgets('Lawyer Dashboard: tapping Call in My Cases shows snackbar', (
    tester,
  ) async {
    final db = DashboardTestHarness.createFakeDb();
    await DashboardTestHarness.seedConnectedCase(
      db,
      caseId: 'case_call_test',
      clientId: 'client_1',
      lawyerId: DashboardTestHarness.verifiedLawyer.id,
    );

    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(
        user: DashboardTestHarness.verifiedLawyer,
        firestore: db,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cases'));
    await tester.pumpAndSettle();

    final callBtn = find.text('Call').first;
    expect(callBtn, findsOneWidget);

    await tester.tap(callBtn);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Direct calling is not available in this demo. Use Chat to contact the client.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Client Dashboard: My Cases sorting and popup screen', (
    tester,
  ) async {
    final db = DashboardTestHarness.createFakeDb();
    final client = DashboardTestHarness.client;

    final caseWithdrawn = CaseModel(
      id: 'case_withdrawn',
      clientId: client.id,
      title: 'Withdrawn Case Title',
      description: 'Withdrawn case description',
      category: CaseCategory.property,
      status: CaseStatus.withdrawn,
      urgency: CaseUrgency.low,
      createdAt: DateTime.utc(2026, 6, 1),
    );

    final caseActive = CaseModel(
      id: 'case_active',
      clientId: client.id,
      title: 'Active Case Title',
      description: 'Active case description',
      category: CaseCategory.family,
      status: CaseStatus.active,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.utc(2026, 6, 2),
    );

    final casePending = CaseModel(
      id: 'case_pending',
      clientId: client.id,
      title: 'Pending Case Title',
      description: 'Pending case description',
      category: CaseCategory.criminal,
      status: CaseStatus.pending,
      urgency: CaseUrgency.high,
      createdAt: DateTime.utc(2026, 6, 3),
    );

    await db
        .collection(CaseRepository.collectionName)
        .doc(caseWithdrawn.id)
        .set(caseWithdrawn.toFirestore());
    await db
        .collection(CaseRepository.collectionName)
        .doc(caseActive.id)
        .set(caseActive.toFirestore());
    await db
        .collection(CaseRepository.collectionName)
        .doc(casePending.id)
        .set(casePending.toFirestore());

    await tester.pumpWidget(
      DashboardTestHarness.wrapClient(user: client, firestore: db),
    );
    await tester.pumpAndSettle();

    // Verify My Cases list is visible and contains seeded cases
    expect(find.text('Pending Case Title'), findsOneWidget);
    expect(find.text('Active Case Title'), findsNWidgets(2));
    expect(find.text('Withdrawn Case Title'), findsOneWidget);

    // Tap View All
    final viewAllCases = find.text('View All').last;
    expect(viewAllCases, findsOneWidget);
    await tester.ensureVisible(viewAllCases);
    await tester.pumpAndSettle();
    await tester.tap(viewAllCases);
    await tester.pumpAndSettle();

    // Now we are in AllCasesScreen
    expect(find.text('My Cases'), findsOneWidget); // AppBar title

    // Check for chips
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Withdrawn'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);

    // Filter by Pending
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(find.text('Pending Case Title'), findsOneWidget);
    expect(find.text('Active Case Title'), findsNothing);
    expect(find.text('Withdrawn Case Title'), findsNothing);

    // Filter by Withdrawn
    await tester.tap(find.text('Withdrawn'));
    await tester.pumpAndSettle();
    expect(find.text('Pending Case Title'), findsNothing);
    expect(find.text('Active Case Title'), findsNothing);
    expect(find.text('Withdrawn Case Title'), findsOneWidget);
  });
}
