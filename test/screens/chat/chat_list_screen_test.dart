import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/repositories/chat_repository.dart';
import 'package:lei_guard/screens/chat/chat_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late FakeFirebaseFirestore fakeDb;
  late ChatRepository repo;

  const clientUser = UserModel(
    id: 'client_1',
    name: 'Tan Wei Ming',
    email: 'tan@example.com',
    phone: '+60112345678',
    role: UserRole.client,
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = ChatRepository(firestore: fakeDb);
  });

  testWidgets('shows empty state when stream emits empty list', (tester) async {
    await tester.pumpWidget(
      wrap(
        ChatListScreen(
          currentUser: clientUser,
          repository: repo,
        ),
      ),
    );

    // Wait for the stream to emit.
    await tester.pumpAndSettle();

    // The empty-state message should be visible.
    expect(find.text('No conversations yet'), findsOneWidget);
    expect(
      find.textContaining(
        'Once a connection request is approved',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows room row when stream emits one room', (tester) async {
    // Seed a room for client_1.
    // Use Timestamp so the orderBy('lastMessageAt') query can sort properly.
    await fakeDb.collection('chat_rooms').doc('case_1_lawyer_1').set({
      'id': 'case_1_lawyer_1',
      'caseId': 'case_1',
      'clientId': 'client_1',
      'lawyerId': 'lawyer_1',
      'participants': ['client_1', 'lawyer_1'],
      'clientName': 'Tan Wei Ming',
      'lawyerName': 'Ahmad Zaki',
      'caseTitle': 'Property dispute',
      'lastMessageText': 'Hello!',
      'lastMessageType': 'text',
      'lastSenderId': 'lawyer_1',
      'lastMessageAt': Timestamp.fromDate(DateTime.utc(2026, 5, 10)),
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 5, 1)),
      'unreadCounts': {'client_1': 1, 'lawyer_1': 0},
    });

    await tester.pumpWidget(
      wrap(
        ChatListScreen(
          currentUser: clientUser,
          repository: repo,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Lawyer name should appear in the list (client views lawyer name).
    expect(find.text('Ahmad Zaki'), findsOneWidget);
    // Case title as subtitle.
    expect(find.text('Property dispute'), findsOneWidget);
    // Last message preview.
    expect(find.text('Hello!'), findsOneWidget);
    // Unread badge (count = 1).
    expect(find.text('1'), findsOneWidget);
  });
}
