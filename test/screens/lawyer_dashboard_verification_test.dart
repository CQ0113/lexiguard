import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/dashboard_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('pending lawyer lands in verification center', (tester) async {
    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(user: DashboardTestHarness.pendingLawyer),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verification Center'), findsOneWidget);
    expect(find.text('Verification in progress'), findsOneWidget);
  });

  testWidgets('pending lawyer sees lock message on My Cases tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(user: DashboardTestHarness.pendingLawyer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cases'));
    await tester.pumpAndSettle();

    expect(find.text('Access locked'), findsOneWidget);
    expect(
      find.text('Complete verification to unlock this section.'),
      findsOneWidget,
    );
  });

  testWidgets('verified lawyer can open My Cases tab', (tester) async {
    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(user: DashboardTestHarness.verifiedLawyer),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cases'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cases you\'ve expressed interest in or are actively working on',
      ),
      findsOneWidget,
    );
    expect(find.text('Access locked'), findsNothing);
  });
}
