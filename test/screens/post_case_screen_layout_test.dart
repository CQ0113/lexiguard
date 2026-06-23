import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/repositories/case_repository.dart';
import 'package:lei_guard/screens/shared/post_case_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('smart matching banner fits on narrow Android screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const client = UserModel(
      id: 'client_layout_test',
      name: 'Client Layout Test',
      email: 'client@example.com',
      phone: '+600000000',
      role: UserRole.client,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PostCaseScreen(
          poster: client,
          caseRepository: CaseRepository(firestore: FakeFirebaseFirestore()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart Matching'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
