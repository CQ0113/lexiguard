import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/repositories/vault_document_repository.dart';
import 'package:lei_guard/screens/client/client_vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('client can rename an uploaded vault document', (tester) async {
    final db = FakeFirebaseFirestore();
    final repository = VaultDocumentRepository(firestore: db);

    await db
        .collection(VaultDocumentRepository.collectionName)
        .doc('doc_1')
        .set({
          'fileName': 'IMG_20260530_1935.jpg',
          'downloadUrl': 'https://example.com/image.jpg',
          'ownerUserId': 'client_1',
          'ownerRole': 'client',
          'storagePath': 'vault/client_1/doc_1/IMG_20260530_1935.jpg',
          'allowedUserIds': ['client_1'],
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23)),
          'sizeBytes': 2048,
          'contentType': 'image/jpeg',
        });

    await tester.pumpWidget(
      MaterialApp(
        home: ClientVaultScreen(userId: 'client_1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('IMG_20260530_1935.jpg'), findsOneWidget);

    await tester.tap(find.byTooltip('Rename document'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Deposit receipt');
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(find.text('Deposit receipt.jpg'), findsOneWidget);
    expect(find.text('IMG_20260530_1935.jpg'), findsNothing);
  });
}
