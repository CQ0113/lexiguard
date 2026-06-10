import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/dashboard_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Client Dashboard: tapping View All activities shows snackbar', (tester) async {
    await tester.pumpWidget(DashboardTestHarness.wrapClient(user: DashboardTestHarness.client));
    await tester.pumpAndSettle();

    final viewAllActivities = find.text('View All').first;
    expect(viewAllActivities, findsOneWidget);
    await tester.ensureVisible(viewAllActivities);
    await tester.pumpAndSettle();

    await tester.tap(viewAllActivities);
    await tester.pumpAndSettle();

    expect(find.text('Full activity history will be available soon.'), findsOneWidget);
  });

  testWidgets('Lawyer Dashboard: tapping Call in My Cases shows snackbar', (tester) async {
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

    expect(find.text('Direct calling is not available in this demo. Use Chat to contact the client.'), findsOneWidget);
  });
}
