import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lei_guard/models/chat_message_model.dart';
import 'package:lei_guard/models/user_model.dart' show UserRole;
import 'package:lei_guard/screens/chat/widgets/message_bubble.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  final sampleMessage = ChatMessage(
    id: 'msg_1',
    roomId: 'case_1_lawyer_1',
    senderId: 'lawyer_1',
    senderRole: UserRole.lawyer,
    type: MessageType.text,
    text: 'Hello, how can I help you?',
    createdAt: DateTime.utc(2026, 5, 10, 9, 30),
  );

  testWidgets('renders own bubble text with navy background', (tester) async {
    await tester.pumpWidget(
      wrap(MessageBubble(message: sampleMessage, isOwn: true)),
    );
    await tester.pumpAndSettle();

    // Message text should be present.
    expect(find.text('Hello, how can I help you?'), findsOneWidget);

    // Own bubble should have navy background.
    final container = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((c) {
          final deco = c.decoration;
          if (deco is BoxDecoration) {
            return deco.color == const Color(0xFF0C1D36);
          }
          return false;
        }, orElse: () => Container());
    expect(container.decoration, isA<BoxDecoration>());
  });

  testWidgets('renders other bubble text with non-navy background', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MessageBubble(message: sampleMessage, isOwn: false)),
    );
    await tester.pumpAndSettle();

    // Message text should be present.
    expect(find.text('Hello, how can I help you?'), findsOneWidget);

    // Other bubble should have light grey background (not navy).
    final bubbleContainers = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) {
          final deco = c.decoration;
          if (deco is BoxDecoration) {
            return deco.color == const Color(0xFFF0F0F5);
          }
          return false;
        })
        .toList();
    expect(bubbleContainers, isNotEmpty);
  });

  // ── Image message ─────────────────────────────────────────────────────────

  testWidgets('renders Image.network widget for image message type', (
    tester,
  ) async {
    final imageMsg = ChatMessage(
      id: 'msg_2',
      roomId: 'case_1_lawyer_1',
      senderId: 'client_1',
      senderRole: UserRole.client,
      type: MessageType.image,
      attachmentStoragePath: 'chat_attachments/case_1_lawyer_1/msg_2_photo.jpg',
      attachmentDownloadUrl: 'https://fake.storage/photo.jpg',
      attachmentName: 'photo.jpg',
      attachmentSize: 204800,
      mimeType: 'image/jpeg',
      createdAt: DateTime.utc(2026, 5, 10, 10, 0),
    );

    await tester.pumpWidget(
      wrap(MessageBubble(message: imageMsg, isOwn: false)),
    );
    // Do not pumpAndSettle — the Image.network will never resolve in tests.
    // Just verify the layout renders with the expected widget tree.
    await tester.pump();

    // Image.network should be present in the widget tree.
    expect(find.byType(Image), findsOneWidget);

    // No '[attachment]' placeholder text any more.
    expect(find.text('[attachment]'), findsNothing);
  });

  testWidgets('image message wraps in GestureDetector for tap-to-zoom', (
    tester,
  ) async {
    final imageMsg = ChatMessage(
      id: 'msg_3',
      roomId: 'case_1_lawyer_1',
      senderId: 'client_1',
      senderRole: UserRole.client,
      type: MessageType.image,
      attachmentDownloadUrl: 'https://fake.storage/photo2.jpg',
      attachmentName: 'photo2.jpg',
      attachmentSize: 102400,
      mimeType: 'image/jpeg',
      createdAt: DateTime.utc(2026, 5, 10, 10, 5),
    );

    await tester.pumpWidget(
      wrap(MessageBubble(message: imageMsg, isOwn: true)),
    );
    await tester.pump();

    // There should be at least one GestureDetector (the tap-to-zoom one +
    // the long-press one in MessageBubble).
    expect(find.byType(GestureDetector), findsWidgets);
  });

  // ── File message ──────────────────────────────────────────────────────────

  testWidgets('file chip renders filename text', (tester) async {
    final fileMsg = ChatMessage(
      id: 'msg_4',
      roomId: 'case_1_lawyer_1',
      senderId: 'lawyer_1',
      senderRole: UserRole.lawyer,
      type: MessageType.file,
      attachmentStoragePath:
          'chat_attachments/case_1_lawyer_1/msg_4_tenancy.pdf',
      attachmentDownloadUrl: 'https://fake.storage/tenancy.pdf',
      attachmentName: 'tenancy_agreement.pdf',
      attachmentSize: 512000, // 500 KB
      mimeType: 'application/pdf',
      createdAt: DateTime.utc(2026, 5, 10, 11, 0),
    );

    await tester.pumpWidget(
      wrap(MessageBubble(message: fileMsg, isOwn: false)),
    );
    await tester.pumpAndSettle();

    // Filename text should be visible.
    expect(find.text('tenancy_agreement.pdf'), findsOneWidget);
  });

  testWidgets('file chip renders formatted size', (tester) async {
    final fileMsg = ChatMessage(
      id: 'msg_5',
      roomId: 'case_1_lawyer_1',
      senderId: 'lawyer_1',
      senderRole: UserRole.lawyer,
      type: MessageType.file,
      attachmentDownloadUrl: 'https://fake.storage/contract.pdf',
      attachmentName: 'contract.pdf',
      attachmentSize: 131072, // 128 KB
      mimeType: 'application/pdf',
      createdAt: DateTime.utc(2026, 5, 10, 11, 5),
    );

    await tester.pumpWidget(
      wrap(MessageBubble(message: fileMsg, isOwn: true)),
    );
    await tester.pumpAndSettle();

    // 131072 bytes → "128 KB"
    expect(find.text('128 KB'), findsOneWidget);
  });

  testWidgets('file chip renders file icon', (tester) async {
    final fileMsg = ChatMessage(
      id: 'msg_6',
      roomId: 'case_1_lawyer_1',
      senderId: 'client_1',
      senderRole: UserRole.client,
      type: MessageType.file,
      attachmentDownloadUrl: 'https://fake.storage/doc.docx',
      attachmentName: 'document.docx',
      attachmentSize: 65536,
      mimeType:
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      createdAt: DateTime.utc(2026, 5, 10, 11, 10),
    );

    await tester.pumpWidget(
      wrap(MessageBubble(message: fileMsg, isOwn: false)),
    );
    await tester.pumpAndSettle();

    // File icon (insert_drive_file_rounded).
    expect(
      find.byIcon(Icons.insert_drive_file_rounded),
      findsOneWidget,
    );
  });

  testWidgets('file chip does not show [attachment] placeholder', (
    tester,
  ) async {
    final fileMsg = ChatMessage(
      id: 'msg_7',
      roomId: 'case_1_lawyer_1',
      senderId: 'lawyer_1',
      senderRole: UserRole.lawyer,
      type: MessageType.file,
      attachmentDownloadUrl: 'https://fake.storage/report.pdf',
      attachmentName: 'report.pdf',
      attachmentSize: 204800,
      mimeType: 'application/pdf',
      createdAt: DateTime.utc(2026, 5, 10, 11, 15),
    );

    await tester.pumpWidget(
      wrap(MessageBubble(message: fileMsg, isOwn: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('[attachment]'), findsNothing);
  });

  // ── Long-press timestamp ──────────────────────────────────────────────────

  testWidgets('long-press on bubble toggles timestamp visibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(MessageBubble(message: sampleMessage, isOwn: false)),
    );
    await tester.pumpAndSettle();

    // Compute the expected timestamp string the same way the widget does,
    // using .toLocal() so the test passes regardless of the host timezone.
    final expectedTimestamp =
        DateFormat('d MMM, h:mm a').format(sampleMessage.createdAt.toLocal());

    // Timestamp should not be visible initially.
    expect(find.text(expectedTimestamp), findsNothing);

    // Long-press the bubble.
    await tester.longPress(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    // Timestamp should now be visible.
    expect(find.text(expectedTimestamp), findsOneWidget);
  });
}
