import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/connection_request_model.dart';
import '../models/case_model.dart'
    show CaseModel, CaseStatus, LawyerRecommendation;
import '../models/user_model.dart' show UserModel, UserRole;

export '../models/connection_request_model.dart'
    show
        ConnectionRequestModel,
        ConnectionRequestStatus,
        ConnectionRequestStatusWire,
        LawyerSnapshot,
        CaseSnapshot,
        ClientReveal,
        DuplicateRequestException,
        RequestDeclinedException,
        CaseAlreadyConnectedException,
        LawyerNotVerifiedException,
        InvalidStatusTransitionException,
        MessageLengthException;

class ConnectionRequestRepository {
  ConnectionRequestRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance,
      _requests = (firestore ?? FirebaseFirestore.instance).collection(
        collectionName,
      );

  static const String collectionName = 'connection_requests';

  final FirebaseFirestore _db;
  final CollectionReference<Map<String, dynamic>> _requests;

  // ── Doc ID convention ───────────────────────────────────────────────────────

  /// Produces a deterministic doc ID that enforces "one request per lawyer per
  /// case" at the DB level.
  static String docIdFor({required String caseId, required String lawyerId}) =>
      '${caseId}_$lawyerId';

  // ── Lawyer writes ───────────────────────────────────────────────────────────

  /// Send (or re-open) an expression of interest.
  ///
  /// Preconditions (validated before the transaction):
  /// - [lawyer.role] must be [UserRole.lawyer]
  /// - [lawyer.canAccessMarketplace] must be `true`
  /// - [targetCase.lawyerId] must be `null`
  /// - [message] length must be in \[50, 500\]
  ///
  /// Existing-request rules:
  /// - `pending` or `approved` → throws [DuplicateRequestException]
  /// - `declined`              → throws [RequestDeclinedException] (terminal)
  /// - `withdrawn` or `expired` → allowed; overwrites doc back to `pending`
  ///
  /// Side effects (single Firestore transaction):
  /// 1. Write / overwrite the `connection_requests` doc with `status=pending`.
  /// 2. Append [lawyer.id] to `case.interestedLawyerIds` via `FieldValue.arrayUnion`.
  Future<void> sendRequest({
    required CaseModel targetCase,
    required UserModel lawyer,
    required String message,
  }) async {
    // ── Pre-flight validation (cheap, no network) ──────────────────────────
    if (lawyer.role != UserRole.lawyer) {
      throw LawyerNotVerifiedException();
    }
    if (!lawyer.canAccessMarketplace) {
      throw LawyerNotVerifiedException();
    }
    if (targetCase.lawyerId != null) {
      throw const CaseAlreadyConnectedException();
    }
    if (message.length < 50 || message.length > 500) {
      throw MessageLengthException(message.length);
    }

    final docId = docIdFor(caseId: targetCase.id, lawyerId: lawyer.id);
    final docRef = _requests.doc(docId);
    final caseRef = _db.collection('cases').doc(targetCase.id);

    // ── Transaction ────────────────────────────────────────────────────────
    await _db.runTransaction((tx) async {
      // Read phase — all reads must happen before writes.
      final existingSnap = await tx.get(docRef);
      final caseSnap = await tx.get(caseRef);

      if (existingSnap.exists) {
        final data = existingSnap.data()!;
        final existing = ConnectionRequestModel.fromFirestore(existingSnap);
        if (existing.isClientInitiated) {
          throw DuplicateRequestException(existing.status);
        }
        final existingStatus = ConnectionRequestStatusWire.fromWire(
          data['status']?.toString(),
        );

        switch (existingStatus) {
          case ConnectionRequestStatus.pending:
          case ConnectionRequestStatus.approved:
            throw DuplicateRequestException(existingStatus);
          case ConnectionRequestStatus.declined:
            throw const RequestDeclinedException();
          case ConnectionRequestStatus.withdrawn:
          case ConnectionRequestStatus.expired:
            // Allow re-open — fall through to the write below.
            break;
        }
      }

      // Write phase
      final now = DateTime.now();
      final snapshot = LawyerSnapshot.fromUser(lawyer);

      final payload = <String, dynamic>{
        'id': docId,
        'caseId': targetCase.id,
        'clientId': targetCase.clientId,
        'lawyerId': lawyer.id,
        'message': message,
        'status': ConnectionRequestStatus.pending.wireValue,
        'initiatedByRole': 'lawyer',
        'requestDirection': 'lawyer_to_client',
        'createdAt': existingSnap.exists
            ? existingSnap
                  .data()!['createdAt'] // preserve original createdAt on re-open
            : Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'lawyerSnapshot': snapshot.toMap(),
        // Clear any stale terminal fields on re-open
        'respondedAt': null,
        'declineReason': null,
        'clientReveal': null,
      };

      tx.set(docRef, payload);

      // Always ensure the lawyer is in interestedLawyerIds.
      // After withdraw/decline the lawyer was removed, so re-adding is required.
      // The Firestore rule requires size+1 only when the ID is absent,
      // so we check the case doc (read above) before deciding to update.
      final currentIds = caseSnap.exists
          ? List<String>.from(
              (caseSnap.data()?['interestedLawyerIds'] as List?) ?? [],
            )
          : <String>[];
      if (!currentIds.contains(lawyer.id)) {
        tx.update(caseRef, {
          'interestedLawyerIds': FieldValue.arrayUnion([lawyer.id]),
        });
      }
    });
  }

  /// Client requests a recommended lawyer for their own pending case.
  ///
  /// Returns the existing status when the deterministic request doc already
  /// exists as `pending` or `approved`; otherwise returns `null` after writing
  /// a new/reopened pending client-to-lawyer request.
  Future<ConnectionRequestStatus?> sendClientRequestToLawyer({
    required CaseModel targetCase,
    required UserModel client,
    required LawyerRecommendation lawyer,
  }) async {
    if (client.role != UserRole.client || client.id != targetCase.clientId) {
      throw StateError('Only the case owner can request a lawyer.');
    }
    if (targetCase.status != CaseStatus.pending) {
      throw StateError('Only pending cases can request a lawyer.');
    }
    final assignedLawyerId = targetCase.lawyerId?.trim();
    if (assignedLawyerId != null && assignedLawyerId.isNotEmpty) {
      throw const CaseAlreadyConnectedException();
    }

    final docId = docIdFor(caseId: targetCase.id, lawyerId: lawyer.lawyerId);
    final docRef = _requests.doc(docId);
    final caseRef = _db.collection('cases').doc(targetCase.id);
    ConnectionRequestStatus? existingStatus;

    await _db.runTransaction((tx) async {
      final existingSnap = await tx.get(docRef);
      final caseSnap = await tx.get(caseRef);

      if (!caseSnap.exists) {
        throw StateError('Case ${targetCase.id} does not exist.');
      }
      final caseData = caseSnap.data()!;
      final caseStatus = caseData['status']?.toString();
      final caseLawyerId = caseData['lawyerId']?.toString().trim();
      if (caseStatus != CaseStatus.pending.name ||
          (caseLawyerId != null && caseLawyerId.isNotEmpty)) {
        throw const CaseAlreadyConnectedException();
      }
      if (caseData['clientId']?.toString() != client.id) {
        throw StateError('Only the case owner can request a lawyer.');
      }

      Object createdAt = Timestamp.fromDate(DateTime.now());
      if (existingSnap.exists) {
        final existing = ConnectionRequestModel.fromFirestore(existingSnap);
        existingStatus = existing.status;
        switch (existing.status) {
          case ConnectionRequestStatus.pending:
          case ConnectionRequestStatus.approved:
            return;
          case ConnectionRequestStatus.declined:
          case ConnectionRequestStatus.withdrawn:
          case ConnectionRequestStatus.expired:
            createdAt = existingSnap.data()?['createdAt'] ?? createdAt;
            break;
        }
      }

      final now = Timestamp.fromDate(DateTime.now());
      tx.set(docRef, {
        'id': docId,
        'caseId': targetCase.id,
        'clientId': targetCase.clientId,
        'lawyerId': lawyer.lawyerId,
        'message': 'The client has requested you for this case.',
        'status': ConnectionRequestStatus.pending.wireValue,
        'initiatedByRole': 'client',
        'requestDirection': 'client_to_lawyer',
        'createdAt': createdAt,
        'updatedAt': now,
        'respondedAt': null,
        'declineReason': null,
        'clientReveal': null,
        'lawyerSnapshot': LawyerSnapshot(
          name: lawyer.lawyerName,
          specialization: lawyer.specialization,
          yearsExperience: lawyer.yearsExperience,
          practiceState: lawyer.practiceState,
          practiceCity: lawyer.practiceCity,
          languages: lawyer.languages,
          hourlyRate: lawyer.hourlyRate,
          verificationStatus: 'auto_verified',
        ).toMap(),
        'caseSnapshot': CaseSnapshot(
          title: targetCase.title,
          category: targetCase.category.name,
          location: targetCase.location,
          budgetRange: targetCase.budgetRange,
          urgency: targetCase.urgency.name,
        ).toMap(),
      });

      existingStatus = null;
    });

    return existingStatus;
  }

  /// Withdraw a pending request. Only valid from `pending` status.
  Future<void> withdrawRequest(String requestId) async {
    final docRef = _requests.doc(requestId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('Request $requestId does not exist.');
      }

      final data = snap.data()!;
      final request = ConnectionRequestModel.fromFirestore(snap);
      if (request.isClientInitiated) {
        throw InvalidStatusTransitionException(
          request.status,
          ConnectionRequestStatus.withdrawn,
        );
      }
      final current = ConnectionRequestStatusWire.fromWire(
        data['status']?.toString(),
      );

      if (current != ConnectionRequestStatus.pending) {
        throw InvalidStatusTransitionException(
          current,
          ConnectionRequestStatus.withdrawn,
        );
      }

      tx.update(docRef, {
        'status': ConnectionRequestStatus.withdrawn.wireValue,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Remove lawyer from case's interestedLawyerIds so the count stays accurate.
      final caseId = data['caseId']?.toString();
      final lawyerId = data['lawyerId']?.toString();
      if (caseId != null && lawyerId != null) {
        final caseRef = _db.collection('cases').doc(caseId);
        tx.update(caseRef, {
          'interestedLawyerIds': FieldValue.arrayRemove([lawyerId]),
        });
      }
    });
  }

  // ── Client writes ───────────────────────────────────────────────────────────

  /// Approve a pending request.
  ///
  /// Transaction (reads before writes per Firestore constraint):
  /// 1. Read request doc.
  /// 2. Assert `status == pending`.
  /// 3. Query sibling pending requests (outside transaction — Firestore
  ///    transactions don't support queries). Re-read each sibling by ID inside
  ///    the transaction to avoid race conditions on their expiry.
  /// 4. Write: flip status → approved, set `clientReveal`, set `respondedAt`.
  /// 5. Write: case doc → `lawyerId = request.lawyerId`, `status = active`.
  /// 6. Write: each sibling → status → expired.
  Future<void> approveRequest({
    required String requestId,
    required UserModel client,
  }) async {
    final docRef = _requests.doc(requestId);

    // Phase 1: read the request to get caseId (needed for sibling query).
    final requestSnap = await docRef.get();
    if (!requestSnap.exists) {
      throw StateError('Request $requestId does not exist.');
    }
    final requestData = requestSnap.data()!;
    final requestModel = ConnectionRequestModel.fromFirestore(requestSnap);
    if (!requestModel.isLawyerInitiated) {
      throw InvalidStatusTransitionException(
        requestModel.status,
        ConnectionRequestStatus.approved,
      );
    }
    final currentStatus = ConnectionRequestStatusWire.fromWire(
      requestData['status']?.toString(),
    );
    if (currentStatus != ConnectionRequestStatus.pending) {
      throw InvalidStatusTransitionException(
        currentStatus,
        ConnectionRequestStatus.approved,
      );
    }
    final caseId = requestData['caseId']?.toString() ?? '';
    final lawyerId = requestData['lawyerId']?.toString() ?? '';

    // Phase 2: query sibling pending requests OUTSIDE the transaction.
    //
    // We must filter by `clientId == auth.uid` so the Firestore `list` rule on
    // connection_requests (which requires the doc's clientId or lawyerId to
    // equal the auth uid) can be statically satisfied — otherwise Firestore
    // rejects the listener with permission-denied. We then narrow to the
    // current case in Dart.
    final siblingsSnap = await _requests
        .where('clientId', isEqualTo: client.id)
        .where('status', isEqualTo: ConnectionRequestStatus.pending.wireValue)
        .get();

    final siblingIds = siblingsSnap.docs
        .where(
          (d) => d.id != requestId && d.data()['caseId']?.toString() == caseId,
        )
        .map((d) => d.id)
        .toList();

    // Phase 3: transaction — reads first, then writes.
    final caseRef = _db.collection('cases').doc(caseId);
    final siblingRefs = siblingIds.map((id) => _requests.doc(id)).toList();

    final now = Timestamp.fromDate(DateTime.now());
    final reveal = ClientReveal.fromUser(client);

    await _db.runTransaction((tx) async {
      final requestTxSnap = await tx.get(docRef);
      if (!requestTxSnap.exists) {
        throw StateError('Request $requestId does not exist.');
      }

      final requestTxData = requestTxSnap.data()!;
      final current = ConnectionRequestStatusWire.fromWire(
        requestTxData['status']?.toString(),
      );
      final freshRequest = ConnectionRequestModel.fromFirestore(requestTxSnap);
      if (!freshRequest.isLawyerInitiated) {
        throw InvalidStatusTransitionException(
          freshRequest.status,
          ConnectionRequestStatus.approved,
        );
      }
      if (freshRequest.status != ConnectionRequestStatus.pending) {
        throw InvalidStatusTransitionException(
          current,
          ConnectionRequestStatus.approved,
        );
      }

      final caseSnap = await tx.get(caseRef);
      final siblingSnaps = await Future.wait(
        siblingRefs.map(tx.get),
      );

      // 1. Flip request to approved.
      tx.update(docRef, {
        'status': ConnectionRequestStatus.approved.wireValue,
        'respondedAt': now,
        'updatedAt': now,
        'clientReveal': reveal.toMap(),
      });

      // 2. Claim the case.
      if (caseSnap.exists) {
        tx.update(caseRef, {
          'lawyerId': lawyerId,
          'status': 'active',
        });
      }

      // 3. Expire siblings (only if still pending).
      for (final snap in siblingSnaps) {
        if (!snap.exists) continue;
        final siblingStatus = ConnectionRequestStatusWire.fromWire(
          snap.data()?['status']?.toString(),
        );
        if (siblingStatus != ConnectionRequestStatus.pending) continue;
        tx.update(snap.reference, {
          'status': ConnectionRequestStatus.expired.wireValue,
          'updatedAt': now,
        });
      }

      // 4. Create (or merge) the chat room.
      final lawyerSnapshotMap =
          requestTxData['lawyerSnapshot'] as Map<String, dynamic>? ?? {};
      final caseTitle = caseSnap.exists
          ? (caseSnap.data()?['title']?.toString() ?? '')
          : '';
      final chatRoomRef = _db.collection('chat_rooms').doc(requestId);
      tx.set(
        chatRoomRef,
        {
          'id': requestId,
          'caseId': caseId,
          'clientId': client.id,
          'lawyerId': lawyerId,
          'participants': [client.id, lawyerId],
          'clientName': reveal.name,
          'lawyerName': lawyerSnapshotMap['name']?.toString() ?? '',
          if (lawyerSnapshotMap['avatarUrl'] != null)
            'lawyerAvatarUrl': lawyerSnapshotMap['avatarUrl'].toString(),
          'caseTitle': caseTitle,
          'lastMessageText': '',
          'lastMessageType': 'text',
          'lastSenderId': '',
          'lastMessageAt': now,
          'createdAt': now,
          'unreadCounts': {client.id: 0, lawyerId: 0},
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Decline a pending request, with an optional reason.
  Future<void> declineRequest({
    required String requestId,
    String? reason,
  }) async {
    final docRef = _requests.doc(requestId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('Request $requestId does not exist.');
      }

      final current = ConnectionRequestStatusWire.fromWire(
        snap.data()!['status']?.toString(),
      );
      final request = ConnectionRequestModel.fromFirestore(snap);
      if (!request.isLawyerInitiated) {
        throw InvalidStatusTransitionException(
          request.status,
          ConnectionRequestStatus.declined,
        );
      }
      if (current != ConnectionRequestStatus.pending) {
        throw InvalidStatusTransitionException(
          current,
          ConnectionRequestStatus.declined,
        );
      }

      final now = Timestamp.fromDate(DateTime.now());
      final payload = <String, dynamic>{
        'status': ConnectionRequestStatus.declined.wireValue,
        'respondedAt': now,
        'updatedAt': now,
      };
      if (reason != null) {
        payload['declineReason'] = reason;
      }
      tx.update(docRef, payload);

      // Mirror withdraw behaviour: drop the lawyer from
      // `case.interestedLawyerIds` so the public counter stays accurate.
      final data = snap.data()!;
      final caseId = data['caseId']?.toString();
      final lawyerId = data['lawyerId']?.toString();
      if (caseId != null && lawyerId != null) {
        final caseRef = _db.collection('cases').doc(caseId);
        tx.update(caseRef, {
          'interestedLawyerIds': FieldValue.arrayRemove([lawyerId]),
        });
      }
    });
  }

  /// Lawyer accepts a pending client-to-lawyer request.
  Future<void> approveClientRequest({
    required String requestId,
    required UserModel lawyer,
  }) async {
    if (lawyer.role != UserRole.lawyer) {
      throw LawyerNotVerifiedException();
    }

    final docRef = _requests.doc(requestId);
    final requestSnap = await docRef.get();
    if (!requestSnap.exists) {
      throw StateError('Request $requestId does not exist.');
    }

    final request = ConnectionRequestModel.fromFirestore(requestSnap);
    if (!request.isClientInitiated ||
        request.lawyerId != lawyer.id ||
        request.status != ConnectionRequestStatus.pending) {
      throw InvalidStatusTransitionException(
        request.status,
        ConnectionRequestStatus.approved,
      );
    }

    final siblingsSnap = await _requests
        .where('caseId', isEqualTo: request.caseId)
        .where('status', isEqualTo: ConnectionRequestStatus.pending.wireValue)
        .get();
    final siblingRefs = siblingsSnap.docs
        .where((doc) => doc.id != requestId)
        .map((doc) => doc.reference)
        .toList();
    final caseRef = _db.collection('cases').doc(request.caseId);

    await _db.runTransaction((tx) async {
      final freshRequestSnap = await tx.get(docRef);
      final caseSnap = await tx.get(caseRef);
      final siblingSnaps = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final ref in siblingRefs) {
        siblingSnaps.add(await tx.get(ref));
      }

      if (!freshRequestSnap.exists || !caseSnap.exists) {
        throw StateError('Request or case no longer exists.');
      }

      final freshRequest = ConnectionRequestModel.fromFirestore(
        freshRequestSnap,
      );
      if (!freshRequest.isClientInitiated ||
          freshRequest.lawyerId != lawyer.id ||
          freshRequest.status != ConnectionRequestStatus.pending) {
        throw InvalidStatusTransitionException(
          freshRequest.status,
          ConnectionRequestStatus.approved,
        );
      }

      final caseData = caseSnap.data()!;
      final caseStatus = caseData['status']?.toString();
      final caseLawyerId = caseData['lawyerId']?.toString().trim();
      if (caseStatus != CaseStatus.pending.name ||
          (caseLawyerId != null && caseLawyerId.isNotEmpty)) {
        throw const CaseAlreadyConnectedException();
      }

      final now = Timestamp.fromDate(DateTime.now());
      tx.update(docRef, {
        'status': ConnectionRequestStatus.approved.wireValue,
        'respondedAt': now,
        'updatedAt': now,
      });
      tx.update(caseRef, {
        'status': CaseStatus.active.name,
        'lawyerId': lawyer.id,
      });

      for (final snap in siblingSnaps) {
        if (!snap.exists) continue;
        final sibling = ConnectionRequestModel.fromFirestore(snap);
        if (sibling.status == ConnectionRequestStatus.pending) {
          tx.update(snap.reference, {
            'status': ConnectionRequestStatus.expired.wireValue,
            'updatedAt': now,
          });
        }
      }
    });
  }

  /// Lawyer rejects a pending client-to-lawyer request.
  Future<void> declineClientRequest({
    required String requestId,
    required UserModel lawyer,
    String? reason,
  }) async {
    if (lawyer.role != UserRole.lawyer) {
      throw LawyerNotVerifiedException();
    }

    final docRef = _requests.doc(requestId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw StateError('Request $requestId does not exist.');
      }

      final request = ConnectionRequestModel.fromFirestore(snap);
      if (!request.isClientInitiated ||
          request.lawyerId != lawyer.id ||
          request.status != ConnectionRequestStatus.pending) {
        throw InvalidStatusTransitionException(
          request.status,
          ConnectionRequestStatus.declined,
        );
      }

      final now = Timestamp.fromDate(DateTime.now());
      final payload = <String, dynamic>{
        'status': ConnectionRequestStatus.declined.wireValue,
        'respondedAt': now,
        'updatedAt': now,
      };
      final trimmed = reason?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        payload['declineReason'] = trimmed;
      }
      tx.update(docRef, payload);
    });
  }

  // ── Reads (streams) ─────────────────────────────────────────────────────────

  /// Pending requests addressed to the given client, newest first.
  Stream<List<ConnectionRequestModel>> streamPendingForClient(String clientId) {
    return _requests
        .where('clientId', isEqualTo: clientId)
        .where('status', isEqualTo: ConnectionRequestStatus.pending.wireValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => _mapDocs(
            snapshot,
          ).where((request) => request.isLawyerInitiated).toList(),
        );
  }

  /// Historical requests (non-pending) for a client, newest first.
  Stream<List<ConnectionRequestModel>> streamHistoryForClient(String clientId) {
    // Firestore `whereIn` supports up to 10 values — safe here.
    return _requests
        .where('clientId', isEqualTo: clientId)
        .where(
          'status',
          whereIn: [
            ConnectionRequestStatus.approved.wireValue,
            ConnectionRequestStatus.declined.wireValue,
            ConnectionRequestStatus.withdrawn.wireValue,
            ConnectionRequestStatus.expired.wireValue,
          ],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => _mapDocs(
            snapshot,
          ).where((request) => request.isLawyerInitiated).toList(),
        );
  }

  /// All requests sent by a given lawyer, newest first.
  Stream<List<ConnectionRequestModel>> streamForLawyer(String lawyerId) {
    return _requests
        .where('lawyerId', isEqualTo: lawyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Pending client-initiated requests addressed to a lawyer, newest first.
  Stream<List<ConnectionRequestModel>> streamPendingClientRequestsForLawyer(
    String lawyerId,
  ) {
    return _requests
        .where('lawyerId', isEqualTo: lawyerId)
        .where('status', isEqualTo: ConnectionRequestStatus.pending.wireValue)
        .where('initiatedByRole', isEqualTo: 'client')
        .snapshots()
        .map((snapshot) {
          final requests = _mapDocs(snapshot);
          requests.sort(
            (left, right) => right.createdAt.compareTo(left.createdAt),
          );
          return requests;
        });
  }

  /// All requests for a given case.
  Stream<List<ConnectionRequestModel>> streamForCase(String caseId) {
    return _requests
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map(_mapDocs);
  }

  /// Single-doc stream — useful for watching one lawyer's request on a case.
  Stream<ConnectionRequestModel?> watchRequest({
    required String caseId,
    required String lawyerId,
  }) {
    final docId = docIdFor(caseId: caseId, lawyerId: lawyerId);
    return _requests.doc(docId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ConnectionRequestModel.fromFirestore(snap);
    });
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  List<ConnectionRequestModel> _mapDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(ConnectionRequestModel.fromFirestore).toList();
  }
}
