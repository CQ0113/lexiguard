import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/case_model.dart';
import 'package:lei_guard/models/user_model.dart';
import 'package:lei_guard/repositories/connection_request_repository.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

UserModel _verifiedLawyer({
  String id = 'lawyer_1',
  String name = 'Ahmad Zaki',
}) {
  return UserModel(
    id: id,
    name: name,
    email: '$id@law.my',
    phone: '+601234567',
    role: UserRole.lawyer,
    barNumber: 'B/MY/99999',
    specialization: 'Property Law',
    firmName: 'Zaki & Partners',
    jurisdiction: 'peninsular',
    yearsExperience: 5,
    rating: 4.5,
    verificationStatus: VerificationStatus.autoVerified,
  );
}

UserModel _unverifiedLawyer() {
  return const UserModel(
    id: 'unverified_lawyer',
    name: 'Unverified Lawyer',
    email: 'unverified@law.my',
    phone: '+60000000000',
    role: UserRole.lawyer,
    verificationStatus: VerificationStatus.pending,
  );
}

UserModel _clientUser({String id = 'client_1'}) {
  return UserModel(
    id: id,
    name: 'Lim Mei Ling',
    email: '$id@gmail.com',
    phone: '+6019876',
    role: UserRole.client,
  );
}

LawyerRecommendation _recommendedLawyer({
  String id = 'lawyer_1',
  String name = 'Ahmad Zaki',
}) {
  return LawyerRecommendation(
    lawyerId: id,
    lawyerName: name,
    specialization: 'Property Law',
    practiceState: 'Selangor',
    practiceCity: 'Shah Alam',
    yearsExperience: 5,
    languages: const ['English', 'Malay'],
    hourlyRate: 300,
    matchPercentage: 91,
    matchReason: 'Matches the case category and location.',
  );
}

CaseModel _openCase({
  String id = 'case_1',
  String? lawyerId,
  List<String> interestedLawyerIds = const [],
}) {
  return CaseModel(
    id: id,
    clientId: 'client_1',
    lawyerId: lawyerId,
    title: 'Property dispute',
    description: 'Need help with a land dispute near KL.',
    category: CaseCategory.property,
    status: CaseStatus.pending,
    urgency: CaseUrgency.medium,
    createdAt: DateTime.utc(2026, 5, 1),
    interestedLawyerIds: interestedLawyerIds,
  );
}

/// Seed a case doc into fake Firestore so that [approveRequest] can update it.
Future<void> _seedCase(FakeFirebaseFirestore db, CaseModel c) async {
  await db.collection('cases').doc(c.id).set(c.toFirestore());
}

/// Helper: send a request and return the request ID.
Future<String> _sendRequest(
  ConnectionRequestRepository repo,
  FakeFirebaseFirestore db, {
  CaseModel? targetCase,
  UserModel? lawyer,
  String message = 'I can assist with your property dispute case here.',
}) async {
  final c = targetCase ?? _openCase();
  final l = lawyer ?? _verifiedLawyer();
  await _seedCase(db, c);
  await repo.sendRequest(targetCase: c, lawyer: l, message: message);
  return ConnectionRequestRepository.docIdFor(caseId: c.id, lawyerId: l.id);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore fakeDb;
  late ConnectionRequestRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = ConnectionRequestRepository(firestore: fakeDb);
  });

  // ── docIdFor ────────────────────────────────────────────────────────────────

  group('docIdFor', () {
    test('produces caseId_lawyerId', () {
      expect(
        ConnectionRequestRepository.docIdFor(
          caseId: 'caseABC',
          lawyerId: 'lawyerXYZ',
        ),
        'caseABC_lawyerXYZ',
      );
    });
  });

  // ── sendRequest — happy path ────────────────────────────────────────────────

  group('sendRequest — happy path', () {
    test('creates a pending doc with correct fields', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      const message = 'I can assist with your property dispute in detail.';
      await _seedCase(fakeDb, openCase);

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: message,
      );

      final docId = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer.id,
      );
      final snap = await fakeDb
          .collection('connection_requests')
          .doc(docId)
          .get();

      expect(snap.exists, isTrue);
      final data = snap.data()!;
      expect(data['status'], 'pending');
      expect(data['caseId'], openCase.id);
      expect(data['clientId'], openCase.clientId);
      expect(data['lawyerId'], lawyer.id);
      expect(data['message'], message);
      expect(data['lawyerSnapshot'], isNotNull);
    });

    test('appends lawyerId to case.interestedLawyerIds', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: 'I can assist with your property dispute in detail.',
      );

      final caseSnap = await fakeDb.collection('cases').doc(openCase.id).get();
      final ids = List<String>.from(
        caseSnap.data()!['interestedLawyerIds'] as List? ?? [],
      );
      expect(ids, contains(lawyer.id));
    });
  });

  group('client-to-lawyer requests', () {
    test(
      'client creates pending request without adding interested lawyer',
      () async {
        final client = _clientUser();
        final openCase = _openCase();
        final lawyer = _recommendedLawyer();
        await _seedCase(fakeDb, openCase);

        final existingStatus = await repo.sendClientRequestToLawyer(
          targetCase: openCase,
          client: client,
          lawyer: lawyer,
        );

        expect(existingStatus, isNull);
        final docId = ConnectionRequestRepository.docIdFor(
          caseId: openCase.id,
          lawyerId: lawyer.lawyerId,
        );
        final requestSnap = await fakeDb
            .collection('connection_requests')
            .doc(docId)
            .get();
        final requestData = requestSnap.data()!;
        expect(requestData['initiatedByRole'], 'client');
        expect(requestData['requestDirection'], 'client_to_lawyer');
        expect(requestData['status'], 'pending');
        expect(requestData['caseSnapshot'], isA<Map>());

        final caseSnap = await fakeDb
            .collection('cases')
            .doc(openCase.id)
            .get();
        final ids = List<String>.from(
          caseSnap.data()!['interestedLawyerIds'] as List? ?? [],
        );
        expect(ids, isEmpty);
      },
    );

    test(
      'client pending request is hidden from client interested stream',
      () async {
        final client = _clientUser();
        final openCase = _openCase();
        await _seedCase(fakeDb, openCase);

        await repo.sendClientRequestToLawyer(
          targetCase: openCase,
          client: client,
          lawyer: _recommendedLawyer(),
        );

        final requests = await repo.streamPendingForClient(client.id).first;
        expect(requests, isEmpty);
      },
    );

    test(
      'lawyer accepts client request and expires sibling requests',
      () async {
        final client = _clientUser();
        final openCase = _openCase();
        final requestedLawyer = _verifiedLawyer();
        final otherLawyer = _verifiedLawyer(id: 'lawyer_2', name: 'Lawyer Two');
        await _seedCase(fakeDb, openCase);

        await repo.sendClientRequestToLawyer(
          targetCase: openCase,
          client: client,
          lawyer: _recommendedLawyer(id: requestedLawyer.id),
        );
        await repo.sendRequest(
          targetCase: openCase,
          lawyer: otherLawyer,
          message: 'I can assist with your property dispute in detail.',
        );

        final requestId = ConnectionRequestRepository.docIdFor(
          caseId: openCase.id,
          lawyerId: requestedLawyer.id,
        );
        await repo.approveClientRequest(
          requestId: requestId,
          lawyer: requestedLawyer,
        );

        final requestSnap = await fakeDb
            .collection('connection_requests')
            .doc(requestId)
            .get();
        expect(requestSnap.data()!['status'], 'approved');

        final caseSnap = await fakeDb
            .collection('cases')
            .doc(openCase.id)
            .get();
        expect(caseSnap.data()!['status'], 'active');
        expect(caseSnap.data()!['lawyerId'], requestedLawyer.id);

        final siblingId = ConnectionRequestRepository.docIdFor(
          caseId: openCase.id,
          lawyerId: otherLawyer.id,
        );
        final siblingSnap = await fakeDb
            .collection('connection_requests')
            .doc(siblingId)
            .get();
        expect(siblingSnap.data()!['status'], 'expired');
      },
    );
  });

  // ── sendRequest — precondition violations ──────────────────────────────────

  group('sendRequest — preconditions', () {
    test('throws LawyerNotVerifiedException for unverified lawyer', () async {
      final lawyer = _unverifiedLawyer();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);

      expect(
        () => repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: 'I can assist with your property dispute in detail.',
        ),
        throwsA(isA<LawyerNotVerifiedException>()),
      );
    });

    test('throws LawyerNotVerifiedException for non-lawyer role', () async {
      final client = _clientUser();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);

      expect(
        () => repo.sendRequest(
          targetCase: openCase,
          lawyer: client,
          message: 'I can assist with your property dispute in detail.',
        ),
        throwsA(isA<LawyerNotVerifiedException>()),
      );
    });

    test(
      'throws CaseAlreadyConnectedException when case.lawyerId is set',
      () async {
        final lawyer = _verifiedLawyer();
        final connectedCase = _openCase(lawyerId: 'some_other_lawyer');
        await _seedCase(fakeDb, connectedCase);

        expect(
          () => repo.sendRequest(
            targetCase: connectedCase,
            lawyer: lawyer,
            message: 'I can assist with your property dispute in detail.',
          ),
          throwsA(isA<CaseAlreadyConnectedException>()),
        );
      },
    );

    test('throws MessageLengthException when message is too short', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);

      expect(
        () => repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: 'Too short',
        ),
        throwsA(isA<MessageLengthException>()),
      );
    });

    test(
      'throws MessageLengthException when message is exactly 501 chars',
      () async {
        final lawyer = _verifiedLawyer();
        final openCase = _openCase();
        await _seedCase(fakeDb, openCase);

        expect(
          () => repo.sendRequest(
            targetCase: openCase,
            lawyer: lawyer,
            message: 'a' * 501,
          ),
          throwsA(isA<MessageLengthException>()),
        );
      },
    );

    test('accepts message of exactly 50 chars', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);

      await expectLater(
        repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: 'a' * 50,
        ),
        completes,
      );
    });

    test('accepts message of exactly 500 chars', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);

      await expectLater(
        repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: 'a' * 500,
        ),
        completes,
      );
    });

    test(
      'throws DuplicateRequestException for existing pending request',
      () async {
        final lawyer = _verifiedLawyer();
        final openCase = _openCase();
        await _seedCase(fakeDb, openCase);
        const msg = 'I can assist with your property dispute in detail.';
        await repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: msg,
        );

        await expectLater(
          repo.sendRequest(targetCase: openCase, lawyer: lawyer, message: msg),
          throwsA(isA<DuplicateRequestException>()),
        );
      },
    );

    test(
      'throws RequestDeclinedException when request was previously declined',
      () async {
        final lawyer = _verifiedLawyer();
        final openCase = _openCase();
        await _seedCase(fakeDb, openCase);
        const msg = 'I can assist with your property dispute in detail.';

        await repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: msg,
        );

        final docId = ConnectionRequestRepository.docIdFor(
          caseId: openCase.id,
          lawyerId: lawyer.id,
        );
        // Manually flip to declined
        await fakeDb.collection('connection_requests').doc(docId).update({
          'status': 'declined',
        });

        await expectLater(
          repo.sendRequest(targetCase: openCase, lawyer: lawyer, message: msg),
          throwsA(isA<RequestDeclinedException>()),
        );
      },
    );
  });

  // ── sendRequest — re-opens a withdrawn request ─────────────────────────────

  group('sendRequest — re-open', () {
    test('re-opens a withdrawn request back to pending', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final docId = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer.id,
      );

      // Withdraw
      await repo.withdrawRequest(docId);

      // Verify withdrawn
      final withdrawnSnap = await fakeDb
          .collection('connection_requests')
          .doc(docId)
          .get();
      expect(withdrawnSnap.data()!['status'], 'withdrawn');

      // Re-send
      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final reopenedSnap = await fakeDb
          .collection('connection_requests')
          .doc(docId)
          .get();
      expect(reopenedSnap.data()!['status'], 'pending');
    });

    test('re-opens an expired request back to pending', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final docId = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer.id,
      );

      // Manually expire
      await fakeDb.collection('connection_requests').doc(docId).update({
        'status': 'expired',
      });

      // Re-send on a fresh case (no lawyerId set)
      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final snap = await fakeDb
          .collection('connection_requests')
          .doc(docId)
          .get();
      expect(snap.data()!['status'], 'pending');
    });
  });

  // ── withdrawRequest ─────────────────────────────────────────────────────────

  group('withdrawRequest', () {
    test('flips pending to withdrawn', () async {
      final docId = await _sendRequest(repo, fakeDb);

      await repo.withdrawRequest(docId);

      final snap = await fakeDb
          .collection('connection_requests')
          .doc(docId)
          .get();
      expect(snap.data()!['status'], 'withdrawn');
    });

    test(
      'throws InvalidStatusTransitionException when already withdrawn',
      () async {
        final docId = await _sendRequest(repo, fakeDb);
        await repo.withdrawRequest(docId);

        await expectLater(
          repo.withdrawRequest(docId),
          throwsA(isA<InvalidStatusTransitionException>()),
        );
      },
    );

    test('throws InvalidStatusTransitionException when approved', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      final client = _clientUser();
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final docId = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer.id,
      );

      await repo.approveRequest(requestId: docId, client: client);

      await expectLater(
        repo.withdrawRequest(docId),
        throwsA(isA<InvalidStatusTransitionException>()),
      );
    });
  });

  // ── approveRequest ──────────────────────────────────────────────────────────

  group('approveRequest', () {
    test(
      'happy path: flips to approved, writes clientReveal, claims case',
      () async {
        final lawyer = _verifiedLawyer();
        final openCase = _openCase();
        final client = _clientUser();
        await _seedCase(fakeDb, openCase);
        const msg = 'I can assist with your property dispute in detail.';

        await repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: msg,
        );

        final docId = ConnectionRequestRepository.docIdFor(
          caseId: openCase.id,
          lawyerId: lawyer.id,
        );

        await repo.approveRequest(requestId: docId, client: client);

        // Check request doc
        final reqSnap = await fakeDb
            .collection('connection_requests')
            .doc(docId)
            .get();
        final data = reqSnap.data()!;
        expect(data['status'], 'approved');
        expect(data['clientReveal'], isNotNull);
        expect((data['clientReveal'] as Map)['name'], client.name);
        expect(data['respondedAt'], isNotNull);

        // Check case doc
        final caseSnap = await fakeDb
            .collection('cases')
            .doc(openCase.id)
            .get();
        expect(caseSnap.data()!['lawyerId'], lawyer.id);
        expect(caseSnap.data()!['status'], 'active');
      },
    );

    test('expires sibling pending requests on the same case', () async {
      final lawyer1 = _verifiedLawyer(id: 'lawyer_1', name: 'Lawyer 1');
      final lawyer2 = _verifiedLawyer(id: 'lawyer_2', name: 'Lawyer 2');
      final openCase = _openCase();
      final client = _clientUser();
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      // Both lawyers send requests
      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer1,
        message: msg,
      );
      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer2,
        message: msg,
      );

      final docId1 = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer1.id,
      );
      final docId2 = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer2.id,
      );

      // Client approves lawyer1
      await repo.approveRequest(requestId: docId1, client: client);

      // lawyer2's request should now be expired
      final siblingSnap = await fakeDb
          .collection('connection_requests')
          .doc(docId2)
          .get();
      expect(siblingSnap.data()!['status'], 'expired');
    });

    test(
      'throws InvalidStatusTransitionException when already approved',
      () async {
        final lawyer = _verifiedLawyer();
        final openCase = _openCase();
        final client = _clientUser();
        await _seedCase(fakeDb, openCase);
        const msg = 'I can assist with your property dispute in detail.';

        await repo.sendRequest(
          targetCase: openCase,
          lawyer: lawyer,
          message: msg,
        );

        final docId = ConnectionRequestRepository.docIdFor(
          caseId: openCase.id,
          lawyerId: lawyer.id,
        );

        await repo.approveRequest(requestId: docId, client: client);

        await expectLater(
          repo.approveRequest(requestId: docId, client: client),
          throwsA(isA<InvalidStatusTransitionException>()),
        );
      },
    );

    test('throws InvalidStatusTransitionException when declined', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      final client = _clientUser();
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final docId = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer.id,
      );

      await repo.declineRequest(requestId: docId, reason: 'Not a fit');

      await expectLater(
        repo.approveRequest(requestId: docId, client: client),
        throwsA(isA<InvalidStatusTransitionException>()),
      );
    });

    test('creates a chat_rooms doc in the same approval batch', () async {
      final lawyer = _verifiedLawyer();
      final openCase = _openCase();
      final client = _clientUser();
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final docId = ConnectionRequestRepository.docIdFor(
        caseId: openCase.id,
        lawyerId: lawyer.id,
      );

      await repo.approveRequest(requestId: docId, client: client);

      // chat_rooms/{roomId} should now exist (roomId == docId).
      final chatSnap =
          await fakeDb.collection('chat_rooms').doc(docId).get();
      expect(chatSnap.exists, isTrue);

      final chatData = chatSnap.data()!;
      expect(chatData['caseId'], openCase.id);
      expect(chatData['clientId'], client.id);
      expect(chatData['lawyerId'], lawyer.id);

      // Participants array contains both parties.
      final participants = List<String>.from(
        chatData['participants'] as List? ?? [],
      );
      expect(participants, containsAll([client.id, lawyer.id]));

      // Client name comes from the ClientReveal built from client.
      expect(chatData['clientName'], client.name);

      // Lawyer name comes from the LawyerSnapshot.
      expect(
        chatData['lawyerName'],
        isNotEmpty,
      );

      // Case title is populated from the case doc.
      expect(chatData['caseTitle'], openCase.title);

      // Unread counts start at zero.
      final counts = Map<String, dynamic>.from(
        chatData['unreadCounts'] as Map? ?? {},
      );
      expect(counts[client.id], 0);
      expect(counts[lawyer.id], 0);
    });
  });

  // ── declineRequest ──────────────────────────────────────────────────────────

  group('declineRequest', () {
    test('flips to declined with reason and sets respondedAt', () async {
      final docId = await _sendRequest(repo, fakeDb);

      await repo.declineRequest(requestId: docId, reason: 'Not a fit');

      final snap = await fakeDb
          .collection('connection_requests')
          .doc(docId)
          .get();
      final data = snap.data()!;
      expect(data['status'], 'declined');
      expect(data['declineReason'], 'Not a fit');
      expect(data['respondedAt'], isNotNull);
    });

    test('flips to declined without reason', () async {
      final docId = await _sendRequest(repo, fakeDb);

      await repo.declineRequest(requestId: docId);

      final snap = await fakeDb
          .collection('connection_requests')
          .doc(docId)
          .get();
      expect(snap.data()!['status'], 'declined');
      // declineReason should be absent or null when not provided
      expect(snap.data()!['declineReason'], isNull);
    });

    test(
      'throws InvalidStatusTransitionException for non-pending status',
      () async {
        final docId = await _sendRequest(repo, fakeDb);
        await repo.withdrawRequest(docId);

        await expectLater(
          repo.declineRequest(requestId: docId),
          throwsA(isA<InvalidStatusTransitionException>()),
        );
      },
    );
  });

  // ── Stream reads ────────────────────────────────────────────────────────────

  group('Stream reads', () {
    test(
      'streamPendingForClient returns only pending requests for that client',
      () async {
        final lawyer1 = _verifiedLawyer(id: 'l1');
        final lawyer2 = _verifiedLawyer(id: 'l2');
        final case1 = _openCase(id: 'case_stream_1');
        final case2 = _openCase(id: 'case_stream_2');
        await _seedCase(fakeDb, case1);
        await _seedCase(fakeDb, case2);
        const msg = 'I can assist with your property dispute in detail.';

        await repo.sendRequest(
          targetCase: case1,
          lawyer: lawyer1,
          message: msg,
        );
        await repo.sendRequest(
          targetCase: case2,
          lawyer: lawyer2,
          message: msg,
        );

        final docId2 = ConnectionRequestRepository.docIdFor(
          caseId: case2.id,
          lawyerId: lawyer2.id,
        );
        await repo.withdrawRequest(docId2); // only docId2 is not pending

        final stream = repo.streamPendingForClient('client_1');
        final result = await stream.first;

        expect(result.length, 1);
        expect(result.first.lawyerId, 'l1');
        expect(result.first.status, ConnectionRequestStatus.pending);
      },
    );

    test('streamHistoryForClient returns only non-pending requests', () async {
      final lawyer1 = _verifiedLawyer(id: 'lh1');
      final lawyer2 = _verifiedLawyer(id: 'lh2');
      final case1 = _openCase(id: 'case_hist_1');
      final case2 = _openCase(id: 'case_hist_2');
      await _seedCase(fakeDb, case1);
      await _seedCase(fakeDb, case2);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(targetCase: case1, lawyer: lawyer1, message: msg);
      await repo.sendRequest(targetCase: case2, lawyer: lawyer2, message: msg);

      final docId1 = ConnectionRequestRepository.docIdFor(
        caseId: case1.id,
        lawyerId: lawyer1.id,
      );
      await repo.withdrawRequest(docId1); // now in history

      final stream = repo.streamHistoryForClient('client_1');
      final result = await stream.first;

      expect(result.any((r) => r.lawyerId == 'lh1'), isTrue);
      // Pending case2 should NOT appear
      expect(result.any((r) => r.lawyerId == 'lh2'), isFalse);
    });

    test('streamForLawyer returns all requests from that lawyer', () async {
      final lawyer = _verifiedLawyer(id: 'l_stream');
      final case1 = _openCase(id: 'case_l1');
      final case2 = _openCase(id: 'case_l2', lawyerId: null);
      await _seedCase(fakeDb, case1);
      await _seedCase(fakeDb, case2);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(targetCase: case1, lawyer: lawyer, message: msg);
      await repo.sendRequest(targetCase: case2, lawyer: lawyer, message: msg);

      final stream = repo.streamForLawyer(lawyer.id);
      final result = await stream.first;

      expect(result.length, 2);
      expect(result.every((r) => r.lawyerId == lawyer.id), isTrue);
    });

    test('streamForCase returns all requests for that case', () async {
      final lawyer1 = _verifiedLawyer(id: 'lc1');
      final lawyer2 = _verifiedLawyer(id: 'lc2');
      final openCase = _openCase(id: 'case_sc1');
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer1,
        message: msg,
      );
      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer2,
        message: msg,
      );

      final stream = repo.streamForCase(openCase.id);
      final result = await stream.first;

      expect(result.length, 2);
      expect(result.every((r) => r.caseId == openCase.id), isTrue);
    });

    test('watchRequest emits null before send, model after send', () async {
      final lawyer = _verifiedLawyer(id: 'l_watch');
      final openCase = _openCase(id: 'case_w1');
      await _seedCase(fakeDb, openCase);
      const msg = 'I can assist with your property dispute in detail.';

      final stream = repo.watchRequest(
        caseId: openCase.id,
        lawyerId: lawyer.id,
      );

      // Collect two events: null (before) and non-null (after send).
      final eventsFuture = stream.take(2).toList();

      // Send after subscribing so the stream captures both states.
      await repo.sendRequest(
        targetCase: openCase,
        lawyer: lawyer,
        message: msg,
      );

      final events = await eventsFuture;
      expect(events.length, 2);
      expect(events[0], isNull);
      expect(events[1], isNotNull);
      expect(events[1]!.status, ConnectionRequestStatus.pending);
    });
  });
}
