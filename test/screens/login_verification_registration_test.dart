import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) {
    return MaterialApp(home: child);
  }

  testWidgets('Sabah registration routes to manual review state', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a Lawyer"));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('auth_email_field')),
      'sabah.lawyer@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth_password_field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('lawyer_legal_name_field')),
      'Siti Rahmah Binti Omar',
    );
    await tester.enterText(
      find.byKey(const Key('lawyer_firm_field')),
      'Rahmah Legal Chambers',
    );

    final jurisdictionDropdown = find.byType(DropdownButton<String>);
    await tester.ensureVisible(jurisdictionDropdown);
    await tester.tap(jurisdictionDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jurisdiction: Sabah Law Society').last);
    await tester.pumpAndSettle();

    final practiceStateField = find.byKey(
      const Key('lawyer_practice_state_field'),
    );
    await tester.ensureVisible(practiceStateField);
    await tester.enterText(practiceStateField, 'Sabah');

    final practiceCityField = find.byKey(
      const Key('lawyer_practice_city_field'),
    );
    await tester.ensureVisible(practiceCityField);
    await tester.enterText(practiceCityField, 'Kota Kinabalu');

    final submitButton = find.text('Register & Start Verification');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle(); // let scroll animation finish before tap
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Automated verification was inconclusive. Our team is reviewing your submission manually.',
      ),
      findsOneWidget,
    );
  });
}
