import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/screens/chat/widgets/lexibot_draft_panel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEXIBOT DRAFT PANEL — widget tests (Step 7)
//
// Uses the [callableOverride] seam to avoid touching Firebase Functions.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Opens the LexiBot sheet from a simple button tap and waits for settle.
  Future<String?> openSheet(
    WidgetTester tester, {
    String? seedQuestion,
    Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
    callableOverride,
  }) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                result = await showLexiBotDraft(
                  ctx,
                  roomId: 'room_test_1',
                  seedQuestion: seedQuestion,
                  callableOverride: callableOverride,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  // ── Test 1: Header, disclaimer, composer, and Cancel are visible ───────────

  testWidgets('opens with header, disclaimer, composer, and Cancel', (
    tester,
  ) async {
    await openSheet(tester);

    // Header title
    expect(find.text('Ask LexiBot'), findsOneWidget);

    // Disclaimer text (partial match)
    expect(
      find.textContaining('General information, not formal legal advice'),
      findsOneWidget,
    );

    // Question text field
    expect(find.byType(TextField), findsOneWidget);

    // Cancel button
    expect(find.text('Cancel'), findsOneWidget);
  });

  // ── Test 2: seedQuestion pre-fills the text field ──────────────────────────

  testWidgets('seedQuestion pre-fills the text field', (tester) async {
    await openSheet(tester, seedQuestion: 'What is section 114 of CPC?');

    expect(
      find.descendant(
        of: find.byType(TextField),
        matching: find.text('What is section 114 of CPC?'),
      ),
      findsOneWidget,
    );
  });

  // ── Test 3: Empty question shows inline error (client-side guard) ──────────

  testWidgets(
    'submitting empty question shows inline error without calling backend',
    (tester) async {
      bool callableCalled = false;

      await openSheet(
        tester,
        callableOverride: (payload) async {
          callableCalled = true;
          return {'answer': 'Should not reach', 'sources': []};
        },
      );

      // Tap submit (the send icon button) with an empty field.
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Inline error must be visible — NOT a SnackBar.
      expect(find.text('Please type a question first.'), findsOneWidget);

      // The callable should NOT have been called.
      expect(callableCalled, isFalse);
    },
  );

  // ── Test 4: Successful response renders answer + source chip ──────────────

  testWidgets('successful response renders answer text and source chip', (
    tester,
  ) async {
    await openSheet(
      tester,
      seedQuestion: 'What does section 5 of the Contracts Act say?',
      callableOverride: (_) async => {
        'answer':
            'Section 5 of the Contracts Act 1950 states that an acceptance '
                'may be revoked at any time before the communication.',
        'sources': [
          {
            'actName': 'Contracts Act 1950',
            'sectionNo': 's 5',
            'sourceUrl': 'https://lom.agc.gov.my/api/contract-act',
          },
        ],
      },
    );

    // Submit
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Answer text
    expect(
      find.textContaining('Section 5 of the Contracts Act 1950'),
      findsOneWidget,
    );

    // Source chip label: actName + sectionNo
    expect(find.text('Contracts Act 1950 s 5'), findsOneWidget);

    // "Sources" section header
    expect(find.text('Sources'), findsOneWidget);
  });

  // ── Test 5: "Insert into composer" returns the answer text ────────────────

  testWidgets('"Insert into composer" pops sheet with answer text', (
    tester,
  ) async {
    String? returnValue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                returnValue = await showLexiBotDraft(
                  ctx,
                  roomId: 'room_test_2',
                  callableOverride: (_) async => {
                    'answer': 'The Contracts Act 1950 applies here.',
                    'sources': [],
                  },
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Type a question then submit
    await tester.enterText(find.byType(TextField), 'Tell me about contracts');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Tap "Insert into composer"
    await tester.tap(find.text('Insert into composer'));
    await tester.pumpAndSettle();

    expect(returnValue, equals('The Contracts Act 1950 applies here.'));
  });

  // ── Test 6: "Cancel" returns null ─────────────────────────────────────────

  testWidgets('"Cancel" pops the sheet with null', (tester) async {
    String? returnValue = 'sentinel'; // distinguish from null
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                returnValue = await showLexiBotDraft(
                  ctx,
                  roomId: 'room_test_3',
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(returnValue, isNull);
  });

  // ── Test 7: FirebaseFunctionsException maps to inline error ───────────────

  testWidgets(
    'FirebaseFunctionsException(unauthenticated) shows inline error message',
    (tester) async {
      await openSheet(
        tester,
        seedQuestion: 'something',
        callableOverride: (_) async {
          throw FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'not authed',
          );
        },
      );

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Error must be inline in the sheet (not a SnackBar).
      expect(
        find.text('Please sign in again to use LexiBot.'),
        findsOneWidget,
      );

      // Sheet should remain open for retry.
      expect(find.text('Ask LexiBot'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    },
  );

  // ── Test 8: After error, user can retry ───────────────────────────────────

  testWidgets('user can retry after an error', (tester) async {
    int callCount = 0;

    await openSheet(
      tester,
      seedQuestion: 'retry me',
      callableOverride: (_) async {
        callCount++;
        if (callCount == 1) {
          throw FirebaseFunctionsException(
            code: 'internal',
            message: '',
          );
        }
        return {
          'answer': 'Second attempt succeeded.',
          'sources': [],
        };
      },
    );

    // First submit → error
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(
      find.text('LexiBot is temporarily unavailable. Try again.'),
      findsOneWidget,
    );

    // Second submit → success
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Second attempt succeeded.'), findsOneWidget);
    // Error is gone.
    expect(
      find.text('LexiBot is temporarily unavailable. Try again.'),
      findsNothing,
    );
  });
}
