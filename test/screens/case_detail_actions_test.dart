import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/case_model.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/repositories/case_action_repository.dart';
import 'package:lei_guard/screens/shared/case_detail_screen.dart';

class _FakeCaseActionHandler implements CaseActionHandler {
  @override
  Future<void> withdrawCase({required String caseId}) async {}

  @override
  Future<void> closeCase({required String caseId, String? reason}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('client sees withdraw action for pending case', (tester) async {
    const client = UserModel(
      id: 'client_1',
      name: 'Client A',
      email: 'client@example.com',
      phone: '+600000000',
      role: UserRole.client,
    );

    final pendingCase = CaseModel(
      id: 'case_1',
      clientId: client.id,
      title: 'Pending Case',
      description: 'Pending case description.',
      category: CaseCategory.family,
      status: CaseStatus.pending,
      urgency: CaseUrgency.low,
      createdAt: DateTime.utc(2026, 5, 1),
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: pendingCase,
          viewer: client,
          actionHandler: _FakeCaseActionHandler(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Withdraw case'), findsOneWidget);
    expect(find.text('Close case'), findsNothing);
  });

  testWidgets('client sees close action for active case', (tester) async {
    const client = UserModel(
      id: 'client_2',
      name: 'Client B',
      email: 'clientb@example.com',
      phone: '+600000001',
      role: UserRole.client,
    );

    final activeCase = CaseModel(
      id: 'case_2',
      clientId: client.id,
      lawyerId: 'lawyer_1',
      title: 'Active Case',
      description: 'Active case description.',
      category: CaseCategory.property,
      status: CaseStatus.active,
      urgency: CaseUrgency.medium,
      createdAt: DateTime.utc(2026, 5, 2),
    );

    await tester.pumpWidget(
      wrap(
        CaseDetailScreen(
          caseModel: activeCase,
          viewer: client,
          actionHandler: _FakeCaseActionHandler(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Close case'), findsOneWidget);
    expect(find.text('Withdraw case'), findsNothing);
  });
}
