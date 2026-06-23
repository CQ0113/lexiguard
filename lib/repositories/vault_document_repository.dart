import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/vault_document_model.dart';

typedef VaultUploadProgress = void Function(double value);

class VaultDocumentRepository {
  VaultDocumentRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storageOverride = storage;

  static const String collectionName = 'vault_documents';

  final FirebaseFirestore _firestore;
  final FirebaseStorage? _storageOverride;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _documents =>
      _firestore.collection(collectionName);

  Stream<List<VaultDocumentModel>> streamClientDocuments({
    required String clientUserId,
  }) {
    return _documents
        .where('ownerUserId', isEqualTo: clientUserId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(VaultDocumentModel.fromFirestore)
              .toList();
          items.sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        });
  }

  Stream<List<VaultDocumentModel>> streamAccessibleDocuments({
    required String userId,
  }) {
    return _documents
        .where('allowedUserIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(VaultDocumentModel.fromFirestore)
              .toList();
          items.sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        });
  }

  Stream<List<VaultDocumentModel>> streamContractsForUser({
    required String userId,
  }) {
    return _documents
        .where('allowedUserIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(VaultDocumentModel.fromFirestore)
              .where((doc) => doc.isContract == true)
              .toList();
          items.sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        });
  }

  Future<Uint8List> _generateSignatureImage(
    List<Map<String, dynamic>> signaturePoints,
  ) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = 3.0
      ..strokeCap = ui.StrokeCap.round
      ..style = ui.PaintingStyle.stroke;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in signaturePoints) {
      final x = (point['x'] as num).toDouble();
      final y = (point['y'] as num).toDouble();
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    if (minX == double.infinity) {
      // Empty points
      minX = 0;
      minY = 0;
      maxX = 100;
      maxY = 50;
    }

    // Add some padding
    const double padding = 10;
    minX -= padding;
    minY -= padding;
    maxX += padding;
    maxY += padding;

    final width = maxX - minX;
    final height = maxY - minY;

    canvas.translate(-minX, -minY);

    ui.Path path = ui.Path();
    bool isFirst = true;

    for (final point in signaturePoints) {
      final x = (point['x'] as num).toDouble();
      final y = (point['y'] as num).toDouble();
      final type = point['type'] as String?;

      if (type == 'move' || isFirst) {
        path.moveTo(x, y);
        isFirst = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image img = await picture.toImage(width.toInt(), height.toInt());
    final ByteData? byteData = await img.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  Future<void> signContract({
    required String documentId,
    required List<Map<String, dynamic>> signaturePoints,
  }) async {
    final docSnapshot = await _documents.doc(documentId).get();
    if (!docSnapshot.exists) return;

    final docData = docSnapshot.data()!;
    final model = VaultDocumentModel.fromFirestore(docSnapshot);

    // 1. Download file bytes
    Uint8List? fileBytes;
    if (model.storagePath.isNotEmpty) {
      fileBytes = await _storage.ref(model.storagePath).getData();
    }

    if (fileBytes != null &&
        fileBytes.isNotEmpty &&
        (model.contentType == 'application/pdf' ||
            model.fileName.toLowerCase().endsWith('.pdf'))) {
      try {
        // 2. Load PDF
        final PdfDocument document = PdfDocument(inputBytes: fileBytes);

        // 3. Generate Signature Image
        final Uint8List sigImageBytes = await _generateSignatureImage(
          signaturePoints,
        );
        final PdfBitmap signatureBitmap = PdfBitmap(sigImageBytes);

        // 4. Determine page and location
        final aiReview =
            docData['contractTerms']?['aiReview'] as Map<String, dynamic>?;
        int pageIndex = 0; // fallback to first page
        String anchorText = "Signature";
        String offset = "above";

        if (aiReview != null) {
          final sigPage = aiReview['signaturePage'];
          if (sigPage is int) {
            pageIndex = sigPage - 1; // 1-indexed to 0-indexed
          }
          if (aiReview['signatureAnchor'] is String) {
            anchorText = aiReview['signatureAnchor'];
          }
          if (aiReview['signatureOffset'] is String) {
            offset = aiReview['signatureOffset'];
          }
        }

        if (pageIndex < 0 || pageIndex >= document.pages.count) {
          pageIndex = document.pages.count - 1; // last page if out of bounds
        }

        final PdfPage page = document.pages[pageIndex];

        // 5. Search for anchor text to get bounds
        final PdfTextExtractor extractor = PdfTextExtractor(document);
        final List<TextLine> lines = extractor.extractTextLines(
          startPageIndex: pageIndex,
        );

        ui.Rect? stampRect;

        final cleanAnchor = anchorText.toLowerCase().trim();
        final anchorWords = cleanAnchor
            .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
            .split(RegExp(r'\s+'))
            .where((w) => w.length > 3)
            .toList();

        for (final line in lines) {
          final text = line.text.toLowerCase();

          bool isMatch = text.contains(cleanAnchor);
          if (!isMatch && anchorWords.isNotEmpty) {
            // Fallback: If exact phrase fails (e.g. split across lines), match significant words
            isMatch = anchorWords.any((w) => text.contains(w));
          }

          if (isMatch) {
            final bounds = line.bounds;
            final imgWidth = 150.0;
            final imgHeight = 75.0;

            if (offset == 'right') {
              stampRect = ui.Rect.fromLTWH(
                bounds.right + 10,
                bounds.top - (imgHeight / 2) + (bounds.height / 2),
                imgWidth,
                imgHeight,
              );
            } else if (offset == 'below') {
              stampRect = ui.Rect.fromLTWH(
                bounds.left,
                bounds.bottom + 5,
                imgWidth,
                imgHeight,
              );
            } else {
              // above (default)
              stampRect = ui.Rect.fromLTWH(
                bounds.left,
                bounds.top -
                    imgHeight -
                    2, // reduced gap to stay closer to the designated line
                imgWidth,
                imgHeight,
              );
            }
            break; // Use the first match on the page
          }
        }

        if (stampRect == null) {
          // Fallback to bottom right
          final imgWidth = 150.0;
          final imgHeight = 75.0;
          final pageSize = page.size;
          stampRect = ui.Rect.fromLTWH(
            pageSize.width - imgWidth - 50,
            pageSize.height - imgHeight - 50,
            imgWidth,
            imgHeight,
          );
        }

        // Draw the image
        page.graphics.drawImage(signatureBitmap, stampRect);

        // Draw the digital seal text for aesthetics
        page.graphics.drawString(
          'DIGITALLY SECURED\n${DateTime.now().toIso8601String()}',
          PdfStandardFont(PdfFontFamily.helvetica, 8),
          bounds: ui.Rect.fromLTWH(
            stampRect.left,
            stampRect.bottom + 2,
            stampRect.width,
            30,
          ),
          brush: PdfBrushes.green,
        );

        // 6. Save PDF and re-upload to client's own vault folder
        final List<int> savedBytes = document.saveSync();
        document.dispose();

        final Uint8List newBytes = Uint8List.fromList(savedBytes);
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser == null) throw Exception("User not authenticated.");

        final safeName = _sanitize("signed_${model.fileName}");
        final newStoragePath = 'vault/${currentUser.uid}/$documentId/$safeName';

        await _storage
            .ref(newStoragePath)
            .putData(
              newBytes,
              SettableMetadata(contentType: 'application/pdf'),
            );
        final String newDownloadUrl = await _storage
            .ref(newStoragePath)
            .getDownloadURL();

        // 7. Update Firestore with new download URL and new storage path
        await _documents.doc(documentId).update({
          'contractStatus': 'signed',
          'signedAt': FieldValue.serverTimestamp(),
          'signaturePoints': signaturePoints,
          'downloadUrl': newDownloadUrl,
          'storagePath': newStoragePath,
        });
        return; // Early return on success
      } catch (e) {
        // Throw error so UI can display it
        throw Exception("Error stamping PDF: $e");
      }
    }

    // Fallback if not PDF
    await _documents.doc(documentId).update({
      'contractStatus': 'signed',
      'signedAt': FieldValue.serverTimestamp(),
      'signaturePoints': signaturePoints,
    });
  }

  Future<void> updateReminderTimestamp(String documentId) async {
    await _documents.doc(documentId).update({
      'lastRemindedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> renameDocument({
    required VaultDocumentModel document,
    required String ownerUserId,
    required String newFileName,
  }) async {
    final normalizedName = _normalizeDisplayName(
      newFileName,
      originalName: document.fileName,
    );

    final docRef = _documents.doc(document.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw StateError('Document ${document.id} does not exist.');
      }

      final data = snapshot.data()!;
      if (data['ownerUserId']?.toString() != ownerUserId) {
        throw StateError('Only the uploader can rename this document.');
      }

      transaction.update(docRef, {
        'fileName': normalizedName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return normalizedName;
  }

  Future<VaultDocumentModel> uploadDocumentBytes({
    required Uint8List bytes,
    required String fileName,
    required String ownerUserId,
    required String ownerRole,
    required List<String> allowedUserIds,
    String? contentType,
    VaultUploadProgress? onProgress,
    bool isContract = false,
    String? contractStatus,
    String? contractType,
    Map<String, dynamic>? contractTerms,
    List<Map<String, dynamic>>? signaturePoints,
  }) async {
    final documentRef = _documents.doc();
    // 使用 Set 去重
    final normalizedAllowedIds = {...allowedUserIds, ownerUserId}.toList();
    final safeName = _sanitize(fileName);
    final storagePath = 'vault/$ownerUserId/${documentRef.id}/$safeName';
    final storageRef = _storage.ref(storagePath);

    // 核心修改：Web / Android 通用上传方法，必须用 putData
    final task = storageRef.putData(
      bytes,
      SettableMetadata(
        contentType: contentType, // 设置了类型，Web端就能直接在线预览
        customMetadata: {
          'ownerUserId': ownerUserId,
          'ownerRole': ownerRole,
          'fileName': fileName,
        },
      ),
    );

    final subscription = task.snapshotEvents.listen(
      (snapshot) {
        if (snapshot.totalBytes <= 0 || onProgress == null) return;
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      },
      onError: (_) {
        // Ignore stream errors here; await task surfaces the same failure.
      },
    );

    try {
      await task;
      onProgress?.call(1);
      final downloadUrl = await storageRef.getDownloadURL();

      final payload = VaultDocumentModel(
        id: documentRef.id,
        fileName: fileName,
        downloadUrl: downloadUrl,
        ownerUserId: ownerUserId,
        ownerRole: ownerRole,
        storagePath: storagePath,
        allowedUserIds: normalizedAllowedIds,
        createdAt:
            null, // 💡 注意：请确保你的 VaultDocumentModel.toFirestore() 中，把 null 转成了 FieldValue.serverTimestamp()
        sizeBytes: bytes.lengthInBytes,
        contentType: contentType,
        isContract: isContract,
        contractStatus: contractStatus,
        contractType: contractType,
        contractTerms: contractTerms,
        signaturePoints: signaturePoints,
      );

      await documentRef.set(payload.toFirestore());
      final saved = await documentRef.get();
      return VaultDocumentModel.fromFirestore(saved);
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> deleteDocument(VaultDocumentModel document) async {
    try {
      if (document.storagePath.isNotEmpty) {
        await _storage.ref(document.storagePath).delete();
      } else if (document.downloadUrl.isNotEmpty) {
        await _storage.refFromURL(document.downloadUrl).delete();
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }

    await _documents.doc(document.id).delete();
  }

  String _sanitize(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty) return 'document';
    return sanitized;
  }

  String _normalizeDisplayName(String value, {required String originalName}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Document name cannot be empty.');
    }
    if (trimmed.length > 120) {
      throw ArgumentError('Document name must be 120 characters or fewer.');
    }
    if (RegExp(r'[\\/\x00-\x1F]').hasMatch(trimmed)) {
      throw ArgumentError('Document name cannot contain path separators.');
    }

    if (_hasFileExtension(trimmed)) return trimmed;

    final extension = _fileExtension(originalName);
    if (extension.isEmpty) return trimmed;
    return '$trimmed$extension';
  }

  bool _hasFileExtension(String value) {
    final dotIndex = value.lastIndexOf('.');
    return dotIndex > 0 && dotIndex < value.length - 1;
  }

  String _fileExtension(String value) {
    final dotIndex = value.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == value.length - 1) return '';
    return value.substring(dotIndex);
  }
}
