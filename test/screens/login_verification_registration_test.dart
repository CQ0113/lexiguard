import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Sabah jurisdiction is available on lawyer registration form', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    await tester.tap(find.text("I'm a Lawyer"));
    await tester.pumpAndSettle();

    final jurisdictionDropdown = find.byType(DropdownButton<String>);
    await tester.ensureVisible(jurisdictionDropdown);
    await tester.tap(jurisdictionDropdown);
    await tester.pumpAndSettle();

    expect(find.text('Jurisdiction: Sabah Law Society').last, findsOneWidget);
  });
}
