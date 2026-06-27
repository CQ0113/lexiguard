import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/case_model.dart';
import 'package:lei_guard/repositories/case_repository.dart';
import 'package:lei_guard/repositories/connection_request_repository.dart';

import '../helpers/dashboard_test_harness.dart';

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

  testWidgets('lawyer CRM dashboard fits on narrow Android screens', (
    tester,
  ) async {
    useNarrowAndroidViewport(tester);

    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(
        user: DashboardTestHarness.verifiedLawyer,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lead Pipeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lawyer CRM dashboard uses live Firestore metrics', (
    tester,
  ) async {
    useNarrowAndroidViewport(tester);

    final db = DashboardTestHarness.createFakeDb();
    final lawyer = DashboardTestHarness.verifiedLawyer;
    const connectedCaseId = 'case_live_connected';

    await DashboardTestHarness.seedConnectedCase(
      db,
      caseId: connectedCaseId,
      clientId: 'client_1',
      lawyerId: lawyer.id,
    );

    final openCase = CaseModel(
      id: 'case_live_open',
      clientId: 'client_live_open',
      title: 'Live Open Case',
      description: 'Open case for live CRM metrics.',
      location: 'KL, Selangor',
      budgetRange: 'RM 200 - 400/hr',
      category: CaseCategory.property,
      status: CaseStatus.pending,
      urgency: CaseUrgency.high,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
    await db
        .collection(CaseRepository.collectionName)
        .doc(openCase.id)
        .set(openCase.toFirestore());

    final approvedRequestId = ConnectionRequestRepository.docIdFor(
      caseId: connectedCaseId,
      lawyerId: lawyer.id,
    );
    await db.collection('connection_requests').doc(approvedRequestId).set({
      'id': approvedRequestId,
      'caseId': connectedCaseId,
      'clientId': 'client_1',
      'lawyerId': lawyer.id,
      'message': 'Connected request for CRM metrics.',
      'status': 'approved',
      'initiatedByRole': 'lawyer',
      'requestDirection': 'lawyer_to_client',
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'respondedAt': Timestamp.fromDate(DateTime.now()),
      'clientReveal': {'name': 'CHU CHENG QING'},
      'lawyerSnapshot': {
        'name': lawyer.name,
        'verificationStatus': 'auto_verified',
      },
    });

    final pendingRequestId = ConnectionRequestRepository.docIdFor(
      caseId: openCase.id,
      lawyerId: lawyer.id,
    );
    await db.collection('connection_requests').doc(pendingRequestId).set({
      'id': pendingRequestId,
      'caseId': openCase.id,
      'clientId': openCase.clientId,
      'lawyerId': lawyer.id,
      'message': 'Pending request for CRM metrics.',
      'status': 'pending',
      'initiatedByRole': 'lawyer',
      'requestDirection': 'lawyer_to_client',
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'lawyerSnapshot': {
        'name': lawyer.name,
        'verificationStatus': 'auto_verified',
      },
    });

    await db.collection('chat_rooms').doc(approvedRequestId).set({
      'id': approvedRequestId,
      'caseId': connectedCaseId,
      'clientId': 'client_1',
      'lawyerId': lawyer.id,
      'participants': ['client_1', lawyer.id],
      'clientName': 'CHU CHENG QING',
      'lawyerName': lawyer.name,
      'caseTitle': 'Property Dispute',
      'lastMessageText': 'Please review the draft.',
      'lastMessageType': 'text',
      'lastSenderId': 'client_1',
      'lastMessageAt': Timestamp.fromDate(DateTime.now()),
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'unreadCounts': {lawyer.id: 2, 'client_1': 0},
    });

    await db.collection('vault_documents').doc('doc_pending_signature').set({
      'fileName': 'Residential Tenancy Agreement.pdf',
      'downloadUrl': 'https://example.com/tenancy.pdf',
      'ownerUserId': lawyer.id,
      'ownerRole': 'lawyer',
      'storagePath': 'vault/${lawyer.id}/doc_pending_signature/file.pdf',
      'allowedUserIds': [lawyer.id, 'client_1'],
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'sizeBytes': 2048,
      'contentType': 'application/pdf',
      'isContract': true,
      'contractStatus': 'pending_signature',
      'contractType': 'tenancy',
    });

    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(user: lawyer, firestore: db),
    );
    await tester.pumpAndSettle();

    expect(find.text('CHU CHENG QING connected'), findsOneWidget);
    expect(find.text('Connected Cases'), findsOneWidget);
    expect(find.text('Pending Docs'), findsOneWidget);
    expect(find.text('Unread Chats'), findsOneWidget);
    expect(find.text('1 pending request'), findsOneWidget);
    expect(find.text('RM 12.4K'), findsNothing);
    expect(find.text('127 reviews'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lawyer My Cases tab fits on narrow Android screens', (
    tester,
  ) async {
    useNarrowAndroidViewport(tester);

    final db = DashboardTestHarness.createFakeDb();
    final lawyer = DashboardTestHarness.verifiedLawyer;

    await DashboardTestHarness.seedConnectedCase(
      db,
      caseId: 'case_connected_layout',
      clientId: 'client_1',
      lawyerId: lawyer.id,
    );

    final openCase = CaseModel(
      id: 'case_open_layout',
      clientId: 'client_layout',
      title: 'Landrod',
      description: 'Open property case for layout regression testing.',
      location: 'Damansara, Selangor',
      budgetRange: 'Flexible / Negotiable',
      category: CaseCategory.property,
      status: CaseStatus.pending,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.utc(2026, 6, 1),
    );
    await db
        .collection(CaseRepository.collectionName)
        .doc(openCase.id)
        .set(openCase.toFirestore());

    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(user: lawyer, firestore: db),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cases'));
    await tester.pumpAndSettle();

    expect(find.text('Search cases or clients...'), findsOneWidget);
    expect(find.text('Flexible / Negotiable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lawyer connected case uses revealed client name', (
    tester,
  ) async {
    useNarrowAndroidViewport(tester);

    final db = DashboardTestHarness.createFakeDb();
    final lawyer = DashboardTestHarness.verifiedLawyer;
    const caseId = 'case_connected_reveal';

    await DashboardTestHarness.seedConnectedCase(
      db,
      caseId: caseId,
      clientId: 'client_1',
      lawyerId: lawyer.id,
    );

    final requestId = ConnectionRequestRepository.docIdFor(
      caseId: caseId,
      lawyerId: lawyer.id,
    );
    await db.collection('connection_requests').doc(requestId).set({
      'id': requestId,
      'caseId': caseId,
      'clientId': 'client_1',
      'lawyerId': lawyer.id,
      'message': 'The client has requested you for this case.',
      'status': 'approved',
      'initiatedByRole': 'client',
      'requestDirection': 'client_to_lawyer',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23, 1, 1)),
      'respondedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23, 1, 2)),
      'clientReveal': {'name': 'CHU CHENG QING'},
      'lawyerSnapshot': {
        'name': lawyer.name,
        'verificationStatus': 'auto_verified',
      },
      'caseSnapshot': {
        'title': 'Property Dispute',
        'category': 'property',
        'urgency': 'medium',
      },
    });

    await tester.pumpWidget(
      DashboardTestHarness.wrapLawyer(user: lawyer, firestore: db),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Cases'));
    await tester.pumpAndSettle();

    expect(find.text('CHU CHENG QING'), findsOneWidget);
    expect(find.text('Ahmad Razif'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
