import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lei_guard/data/dummy_data.dart';
import 'package:lei_guard/models/case_model.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/repositories/case_repository.dart';
import 'package:lei_guard/repositories/chat_repository.dart';
import 'package:lei_guard/repositories/connection_request_repository.dart';
import 'package:lei_guard/repositories/vault_document_repository.dart';
import 'package:lei_guard/screens/client/client_dashboard_screen.dart';
import 'package:lei_guard/screens/lawyer/lawyer_dashboard_screen.dart';

class DashboardTestHarness {
  DashboardTestHarness._();

  static FakeFirebaseFirestore createFakeDb() => FakeFirebaseFirestore();

  static Future<void> seedConnectedCase(
    FakeFirebaseFirestore db, {
    required String caseId,
    required String clientId,
    required String lawyerId,
  }) async {
    final caseModel = CaseModel(
      id: caseId,
      clientId: clientId,
      lawyerId: lawyerId,
      title: 'Property Dispute',
      description: 'Connected case for dashboard widget tests.',
      category: CaseCategory.property,
      status: CaseStatus.active,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.utc(2026, 5, 1),
    );
    await db.collection(CaseRepository.collectionName).doc(caseId).set(
      caseModel.toFirestore(),
    );
  }

  static Widget wrapClient({
    required UserModel user,
    FakeFirebaseFirestore? firestore,
  }) {
    final db = firestore ?? createFakeDb();
    final vaultRepository = VaultDocumentRepository(firestore: db);
    return MaterialApp(
      home: ClientDashboardScreen(
        user: user,
        caseRepository: CaseRepository(firestore: db),
        connectionRequestRepository: ConnectionRequestRepository(firestore: db),
        chatRepository: ChatRepository(firestore: db),
        vaultRepository: vaultRepository,
      ),
    );
  }

  static Widget wrapLawyer({
    required UserModel user,
    FakeFirebaseFirestore? firestore,
  }) {
    final db = firestore ?? createFakeDb();
    return MaterialApp(
      home: LawyerDashboardScreen(
        user: user,
        caseRepository: CaseRepository(firestore: db),
        connectionRequestRepository: ConnectionRequestRepository(firestore: db),
        chatRepository: ChatRepository(firestore: db),
      ),
    );
  }

  static UserModel get client => DummyData.users.firstWhere((u) => u.id == 'client_1');

  static UserModel get verifiedLawyer =>
      DummyData.users.firstWhere((u) => u.id == 'lawyer_1');

  static UserModel get pendingLawyer => DummyData.firstPendingLawyer;
}
