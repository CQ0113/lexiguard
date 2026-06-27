import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/repositories/vault_document_repository.dart';
import 'package:lei_guard/screens/lawyer/lawyer_vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void useNarrowAndroidViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('lawyer vault pending contract card fits on narrow screens', (
    tester,
  ) async {
    useNarrowAndroidViewport(tester);

    final db = FakeFirebaseFirestore();
    final repository = VaultDocumentRepository(firestore: db);

    await db
        .collection(VaultDocumentRepository.collectionName)
        .doc('contract_1')
        .set({
          'fileName': 'Residential_Tenancy_Agreement_2026.pdf',
          'downloadUrl': 'https://example.com/contract.pdf',
          'ownerUserId': 'lawyer_1',
          'ownerRole': 'lawyer',
          'storagePath': 'vault/lawyer_1/contract_1/contract.pdf',
          'allowedUserIds': ['lawyer_1', 'client_1'],
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23)),
          'sizeBytes': 5120,
          'contentType': 'application/pdf',
          'isContract': true,
          'contractStatus': 'pending_signature',
          'contractType': 'Residential Tenancy Agreement',
        });

    await tester.pumpWidget(
      MaterialApp(
        home: LawyerVaultScreen(
          lawyerUserId: 'lawyer_1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspace Documents'), findsOneWidget);
    expect(find.byTooltip('Document actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
