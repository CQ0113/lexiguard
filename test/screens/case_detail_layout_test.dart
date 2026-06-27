import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/case_model.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/repositories/case_action_repository.dart';
import 'package:lei_guard/repositories/connection_request_repository.dart';
import 'package:lei_guard/screens/shared/case_detail_screen.dart';
import 'package:lei_guard/services/case_matching_service.dart';

class _NoopCaseActionHandler implements CaseActionHandler {
  @override
  Future<void> closeCase({required String caseId, String? reason}) async {}

  @override
  Future<void> recommendLawyers({
    required String caseId,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> withdrawCase({required String caseId}) async {}
}

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

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets(
    'case detail interested lawyers empty state fits on narrow Android screens',
    (tester) async {
      useNarrowAndroidViewport(tester);

      const client = UserModel(
        id: 'client_layout',
        name: 'Client Layout',
        email: 'client.layout@example.com',
        phone: '+60000000002',
        role: UserRole.client,
      );

      final caseModel = CaseModel(
        id: 'case_detail_layout',
        clientId: client.id,
        title: 'Deposit recovery from landlord',
        description:
            'The landlord has not returned the deposit after checkout.',
        location: 'Kuala Lumpur, Selangor',
        budgetRange: 'RM 200 - 400/hr',
        category: CaseCategory.property,
        status: CaseStatus.pending,
        urgency: CaseUrgency.medium,
        createdAt: DateTime.utc(2026, 6, 1),
        recommendationStatus: 'completed',
      );

      await tester.pumpWidget(
        wrap(
          CaseDetailScreen(
            caseModel: caseModel,
            viewer: client,
            repository: ConnectionRequestRepository(
              firestore: FakeFirebaseFirestore(),
            ),
            actionHandler: _NoopCaseActionHandler(),
            subscribeToLiveUpdates: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Interested Lawyers'), findsOneWidget);
      expect(
        find.text('No lawyers have expressed interest yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lawyer case detail status row and pending action fit on narrow Android screens',
    (tester) async {
      useNarrowAndroidViewport(tester);

      final firestore = FakeFirebaseFirestore();
      final repo = ConnectionRequestRepository(firestore: firestore);

      const lawyer = UserModel(
        id: 'lawyer_layout',
        name: 'Layout Lawyer',
        email: 'lawyer.layout@example.com',
        phone: '+60000000003',
        role: UserRole.lawyer,
        specialization: 'Property',
        hourlyRate: 100,
        yearsExperience: 3,
        verificationStatus: VerificationStatus.autoVerified,
      );

      final caseModel = CaseModel(
        id: 'case_lawyer_layout',
        clientId: 'client_layout',
        title: 'Landlord refusing to return the deposit',
        description:
            "My landlord don't want to return the deposit even our agreement has completed.",
        location: 'Johor Bahru, Johor',
        budgetRange: 'RM 100 - 200/hr',
        category: CaseCategory.property,
        status: CaseStatus.pending,
        urgency: CaseUrgency.medium,
        createdAt: DateTime.utc(2026, 6, 24),
        interestedLawyerIds: const ['lawyer_layout'],
      );

      final requestId = ConnectionRequestRepository.docIdFor(
        caseId: caseModel.id,
        lawyerId: lawyer.id,
      );
      await firestore
          .collection(ConnectionRequestRepository.collectionName)
          .doc(requestId)
          .set(
            ConnectionRequestModel(
              id: requestId,
              caseId: caseModel.id,
              clientId: caseModel.clientId,
              lawyerId: lawyer.id,
              message:
                  'I can review the tenancy agreement and advise on deposit recovery.',
              status: ConnectionRequestStatus.pending,
              createdAt: DateTime.utc(2026, 6, 24, 9),
              updatedAt: DateTime.utc(2026, 6, 24, 9),
              lawyerSnapshot: LawyerSnapshot.fromUser(lawyer),
            ).toFirestore(),
          );

      await tester.pumpWidget(
        wrap(
          CaseDetailScreen(
            caseModel: caseModel,
            viewer: lawyer,
            matchResult: const MatchResult(
              caseId: 'case_lawyer_layout',
              matchPercentage: 100,
              matchReason:
                  'This case perfectly matches your Property specialization, primary practice location in Johor Bahru, and hourly rate.',
            ),
            repository: repo,
            actionHandler: _NoopCaseActionHandler(),
            subscribeToLiveUpdates: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open — Seeking Lawyer'), findsOneWidget);
      expect(find.text('1 lawyer interested'), findsOneWidget);
      expect(find.text('AI Match Analysis'), findsOneWidget);
      expect(find.text('100% Match'), findsOneWidget);
      expect(find.text('Pending review'), findsOneWidget);
      expect(find.text('Withdraw'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
