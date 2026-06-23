import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/vault_document_model.dart';
import 'package:lei_guard/repositories/vault_document_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late VaultDocumentRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = VaultDocumentRepository(firestore: db);
  });

  Future<VaultDocumentModel> seedDocument({
    String id = 'doc_1',
    String ownerUserId = 'client_1',
    String fileName = 'landlord_deposit.pdf',
  }) async {
    await db.collection(VaultDocumentRepository.collectionName).doc(id).set({
      'fileName': fileName,
      'downloadUrl': 'https://example.com/$fileName',
      'ownerUserId': ownerUserId,
      'ownerRole': 'client',
      'storagePath': 'vault/$ownerUserId/$id/$fileName',
      'allowedUserIds': [ownerUserId],
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 1)),
      'sizeBytes': 1024,
      'contentType': 'application/pdf',
    });

    final snapshot = await db
        .collection(VaultDocumentRepository.collectionName)
        .doc(id)
        .get();
    return VaultDocumentModel.fromFirestore(snapshot);
  }

  test('renameDocument updates the displayed filename', () async {
    final document = await seedDocument();

    final renamed = await repository.renameDocument(
      document: document,
      ownerUserId: 'client_1',
      newFileName: 'Tenancy agreement',
    );

    expect(renamed, 'Tenancy agreement.pdf');

    final snapshot = await db
        .collection(VaultDocumentRepository.collectionName)
        .doc(document.id)
        .get();
    expect(snapshot.data()!['fileName'], 'Tenancy agreement.pdf');
    expect(snapshot.data()!['updatedAt'], isA<Timestamp>());
  });

  test('renameDocument rejects non-owners', () async {
    final document = await seedDocument();

    await expectLater(
      repository.renameDocument(
        document: document,
        ownerUserId: 'lawyer_1',
        newFileName: 'Other name.pdf',
      ),
      throwsStateError,
    );

    final snapshot = await db
        .collection(VaultDocumentRepository.collectionName)
        .doc(document.id)
        .get();
    expect(snapshot.data()!['fileName'], 'landlord_deposit.pdf');
  });
}
