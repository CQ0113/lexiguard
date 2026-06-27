import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/repositories/connection_request_repository.dart';
import 'package:lei_guard/screens/shared/dynamic_legal_form_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('lawyer can filter and select a connected client', (
    tester,
  ) async {
    final db = FakeFirebaseFirestore();
    const lawyerId = 'lawyer_1';
    await db.collection('connection_requests').doc('case_1_lawyer_1').set({
      'id': 'case_1_lawyer_1',
      'caseId': 'case_1',
      'clientId': 'client_chu',
      'lawyerId': lawyerId,
      'message': 'The client has requested you for this case.',
      'status': 'approved',
      'initiatedByRole': 'client',
      'requestDirection': 'client_to_lawyer',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23, 1, 1)),
      'respondedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 23, 1, 2)),
      'clientReveal': {'name': 'CHU CHENG QING'},
      'lawyerSnapshot': {
        'name': 'Ahmad Zaki',
        'verificationStatus': 'auto_verified',
      },
      'caseSnapshot': {
        'title': 'Land Arguments',
        'category': 'property',
        'urgency': 'low',
      },
    });
    await db.collection('connection_requests').doc('case_2_lawyer_1').set({
      'id': 'case_2_lawyer_1',
      'caseId': 'case_2',
      'clientId': 'client_tan',
      'lawyerId': lawyerId,
      'message': 'The client has requested you for this case.',
      'status': 'approved',
      'initiatedByRole': 'client',
      'requestDirection': 'client_to_lawyer',
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 6, 22, 1)),
      'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 22, 1, 1)),
      'respondedAt': Timestamp.fromDate(DateTime.utc(2026, 6, 22, 1, 2)),
      'clientReveal': {'name': 'Tan Wei Ming'},
      'lawyerSnapshot': {
        'name': 'Ahmad Zaki',
        'verificationStatus': 'auto_verified',
      },
      'caseSnapshot': {
        'title': 'Rental Dispute',
        'category': 'property',
        'urgency': 'medium',
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: DynamicLegalFormPage(
          currentLawyerId: lawyerId,
          connectionRequestRepository: ConnectionRequestRepository(
            firestore: db,
          ),
          templateData: const {
            'template_id': 'TEST',
            'template_name': 'Letter of Demand',
            'category': 'Property',
            'dynamic_fields': <Map<String, Object?>>[],
            'document_body': 'Client Signature',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byKey(const Key('connected_client_selector_field'));
    expect(field, findsOneWidget);

    await tester.tap(field);
    await tester.enterText(field, 'chu');
    await tester.pumpAndSettle();

    expect(find.text('CHU CHENG QING'), findsOneWidget);
    expect(find.text('Land Arguments'), findsOneWidget);
    expect(find.text('Tan Wei Ming'), findsNothing);

    await tester.tap(find.text('CHU CHENG QING'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Client ID: client_chu'), findsOneWidget);
  });
}
