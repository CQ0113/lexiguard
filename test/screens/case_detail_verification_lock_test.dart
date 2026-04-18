import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/data/dummy_data.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/screens/shared/case_detail_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('rejected lawyer sees rejected-specific lock message', (
    tester,
  ) async {
    const rejectedLawyer = UserModel(
      id: 'lawyer_rejected_1',
      name: 'Rejected Lawyer',
      email: 'rejected@example.com',
      phone: '+60000000090',
      role: UserRole.lawyer,
      verificationStatus: VerificationStatus.rejected,
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: DummyData.openCases.first,
          viewer: rejectedLawyer,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your verification was rejected. Update your legal details and resubmit to regain case marketplace access.',
      ),
      findsOneWidget,
    );
  });
}
