import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/connection_request_model.dart';
import '../models/case_model.dart' show CaseModel;
import '../models/user_model.dart' show UserModel, UserRole;

export '../models/connection_request_model.dart'
    show
        ConnectionRequestModel,
        ConnectionRequestStatus,
        ConnectionRequestStatusWire,
        LawyerSnapshot,
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
      _requests =
          (firestore ?? FirebaseFirestore.instance).collection(collectionName);

  static const String collectionName = 'connection_requests';

  final FirebaseFirestore _db;
  final CollectionReference<Map<String, dynamic>> _requests;

  // ── Doc ID convention ───────────────────────────────────────────────────────

  /// Produces a deterministic doc ID that enforces "one request per lawyer per
  /// case" at the DB level.
  static String docIdFor({
    required String caseId,
    required String lawyerId,
  }) => '${caseId}_$lawyerId';

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
    final caseRef =
        _db.collection('cases').doc(targetCase.id);

    // ── Transaction ────────────────────────────────────────────────────────
    await _db.runTransaction((tx) async {
      // Read phase — all reads must happen before writes.
      final existingSnap = await tx.get(docRef);

      if (existingSnap.exists) {
        final data = existingSnap.data()!;
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
        'createdAt': existingSnap.exists
            ? existingSnap.data()!['createdAt'] // preserve original createdAt on re-open
            : Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'lawyerSnapshot': snapshot.toMap(),
        // Clear any stale terminal fields on re-open
        'respondedAt': null,
        'declineReason': null,
        'clientReveal': null,
      };

      tx.set(docRef, payload);
      // On re-send the lawyer is already in interestedLawyerIds; arrayUnion
      // would be a no-op and the Firestore rule requires size+1, so skip.
      if (!existingSnap.exists) {
        tx.update(caseRef, {
          'interestedLawyerIds': FieldValue.arrayUnion([lawyer.id]),
        });
      }
    });
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
    final siblingsSnap = await _requests
        .where('caseId', isEqualTo: caseId)
        .where('status', isEqualTo: ConnectionRequestStatus.pending.wireValue)
        .get();

    final siblingIds = siblingsSnap.docs
        .map((d) => d.id)
        .where((id) => id != requestId)
        .toList();

    // Phase 3: transaction — reads first, then writes.
    final caseRef = _db.collection('cases').doc(caseId);
    final siblingRefs = siblingIds.map((id) => _requests.doc(id)).toList();

    await _db.runTransaction((tx) async {
      // ── Reads ──────────────────────────────────────────────────────────────
      final reqSnap = await tx.get(docRef);
      final caseSnap = await tx.get(caseRef);

      // Re-read siblings inside transaction.
      final siblingSnaps = <DocumentSnapshot>[];
      for (final ref in siblingRefs) {
        siblingSnaps.add(await tx.get(ref));
      }

      // Guard: re-check status inside transaction.
      final freshStatus = ConnectionRequestStatusWire.fromWire(
        reqSnap.data()?['status']?.toString(),
      );
      if (freshStatus != ConnectionRequestStatus.pending) {
        throw InvalidStatusTransitionException(
          freshStatus,
          ConnectionRequestStatus.approved,
        );
      }

      final now = Timestamp.fromDate(DateTime.now());
      final reveal = ClientReveal.fromUser(client);

      // ── Writes ─────────────────────────────────────────────────────────────
      // 1. Flip request to approved.
      tx.update(docRef, {
        'status': ConnectionRequestStatus.approved.wireValue,
        'respondedAt': now,
        'updatedAt': now,
        'clientReveal': reveal.toMap(),
      });

      // 2. Claim the case.
      final caseUpdate = <String, dynamic>{
        'lawyerId': lawyerId,
        'status': 'active',
      };
      if (caseSnap.exists) {
        tx.update(caseRef, caseUpdate);
      }

      // 3. Expire siblings.
      for (final snap in siblingSnaps) {
        if (snap.exists) {
          final snapData = snap.data() as Map<String, dynamic>?;
          final sibStatus = ConnectionRequestStatusWire.fromWire(
            snapData?['status']?.toString(),
          );
          if (sibStatus == ConnectionRequestStatus.pending) {
            tx.update(snap.reference, {
              'status': ConnectionRequestStatus.expired.wireValue,
              'updatedAt': now,
            });
          }
        }
      }
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
    });
  }

  // ── Reads (streams) ─────────────────────────────────────────────────────────

  /// Pending requests addressed to the given client, newest first.
  Stream<List<ConnectionRequestModel>> streamPendingForClient(
    String clientId,
  ) {
    return _requests
        .where('clientId', isEqualTo: clientId)
        .where('status', isEqualTo: ConnectionRequestStatus.pending.wireValue)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// Historical requests (non-pending) for a client, newest first.
  Stream<List<ConnectionRequestModel>> streamHistoryForClient(
    String clientId,
  ) {
    // Firestore `whereIn` supports up to 10 values — safe here.
    return _requests
        .where('clientId', isEqualTo: clientId)
        .where('status', whereIn: [
          ConnectionRequestStatus.approved.wireValue,
          ConnectionRequestStatus.declined.wireValue,
          ConnectionRequestStatus.withdrawn.wireValue,
          ConnectionRequestStatus.expired.wireValue,
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
  }

  /// All requests sent by a given lawyer, newest first.
  Stream<List<ConnectionRequestModel>> streamForLawyer(String lawyerId) {
    return _requests
        .where('lawyerId', isEqualTo: lawyerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapDocs);
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
    return snapshot.docs
        .map(ConnectionRequestModel.fromFirestore)
        .toList();
  }
}
