import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/data/dummy_data.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/screens/shared/case_detail_screen.dart';
import 'package:lei_guard/services/case_matching_service.dart';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lei_guard/repositories/connection_request_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('CaseDetailScreen renders AI Match Analysis card when matchResult is provided', (
    tester,
  ) async {
    const verifiedLawyer = UserModel(
      id: 'lawyer_verified_test',
      name: 'Aishah Kamal',
      email: 'aishah@example.com',
      phone: '+60000000001',
      role: UserRole.lawyer,
      verificationStatus: VerificationStatus.autoVerified,
    );

    const testMatchResult = MatchResult(
      caseId: 'case_open_1',
      matchPercentage: 92,
      matchReason: 'This case is located in Cyberjaya and fits your specialization in Commercial Law.',
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: DummyData.openCases.first,
          viewer: verifiedLawyer,
          matchResult: testMatchResult,
          subscribeToLiveUpdates: false,
          repository: ConnectionRequestRepository(firestore: FakeFirebaseFirestore()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Match Analysis'), findsOneWidget);
    expect(find.text('92% Match'), findsOneWidget);
    expect(
      find.text('This case is located in Cyberjaya and fits your specialization in Commercial Law.'),
      findsOneWidget,
    );
  });
}
