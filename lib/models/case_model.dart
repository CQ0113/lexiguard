import 'package:cloud_firestore/cloud_firestore.dart';

// Case Model — ready for Firebase Firestore
// Collection path: 'cases'

enum CaseStatus { active, pending, closed, withdrawn }

enum CaseUrgency { low, medium, high }

enum CaseCategory { property, family, criminal, commercial, employment, other }

class LawyerRecommendation {
  final String lawyerId;
  final String lawyerName;
  final String specialization;
  final String practiceState;
  final String practiceCity;
  final int yearsExperience;
  final List<String> languages;
  final double hourlyRate;
  final int matchPercentage;
  final String matchReason;

  const LawyerRecommendation({
    required this.lawyerId,
    required this.lawyerName,
    required this.specialization,
    required this.practiceState,
    required this.practiceCity,
    required this.yearsExperience,
    required this.languages,
    required this.hourlyRate,
    required this.matchPercentage,
    this.matchReason = '',
  });

  factory LawyerRecommendation.fromMap(Map<String, dynamic> map) {
    final matchPercentage = _readMatchPercentage(map);
    final matchReason = _readMatchReason(map);

    return LawyerRecommendation(
      lawyerId: map['lawyerId']?.toString() ?? '',
      lawyerName: map['lawyerName']?.toString() ?? '',
      specialization: map['specialization']?.toString() ?? '',
      practiceState: map['practiceState']?.toString() ?? '',
      practiceCity: map['practiceCity']?.toString() ?? '',
      yearsExperience: (map['yearsExperience'] as num?)?.toInt() ?? 0,
      languages: List<String>.from(map['languages'] as List? ?? []),
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      matchPercentage: matchPercentage,
      matchReason: matchReason,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lawyerId': lawyerId,
      'lawyerName': lawyerName,
      'specialization': specialization,
      'practiceState': practiceState,
      'practiceCity': practiceCity,
      'yearsExperience': yearsExperience,
      'languages': languages,
      'hourlyRate': hourlyRate,
      'matchPercentage': matchPercentage,
      'matchScore': matchPercentage,
      'matchReason': matchReason,
      if (matchReason.trim().isNotEmpty) 'matchReasons': [matchReason],
    };
  }

  Map<String, dynamic> toMap() {
    return toFirestore();
  }

  static int _readMatchPercentage(Map<String, dynamic> map) {
    final rawValue = map['matchPercentage'] ?? map['matchScore'];
    return ((rawValue as num?)?.round() ?? 0).clamp(0, 100);
  }

  static String _readMatchReason(Map<String, dynamic> map) {
    final directReason = map['matchReason']?.toString().trim();
    if (directReason != null && directReason.isNotEmpty) {
      return directReason;
    }

    final reasons = map['matchReasons'];
    if (reasons is List) {
      final usableReasons = reasons
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty);
      return usableReasons.join(' ');
    }

    return '';
  }
}

class CaseAttachment {
  final String id;
  final String fileName;
  final String downloadUrl;
  final String storagePath;
  final int sizeBytes;
  final String? contentType;
  final DateTime uploadedAt;

  const CaseAttachment({
    required this.id,
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
    required this.sizeBytes,
    this.contentType,
    required this.uploadedAt,
  });

  factory CaseAttachment.fromMap(Map<String, dynamic> map) {
    return CaseAttachment(
      id: map['id']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      downloadUrl: map['downloadUrl']?.toString() ?? '',
      storagePath: map['storagePath']?.toString() ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      contentType: map['contentType']?.toString(),
      uploadedAt:
          CaseModel._readDateTime(map['uploadedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'sizeBytes': sizeBytes,
      'contentType': contentType,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'sizeBytes': sizeBytes,
      'contentType': contentType,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}

class CaseModel {
  final String id;
  final String clientId;
  final String? lawyerId;
  final String title;
  final String description;
  final String? location;
  final String? budgetRange;
  final CaseCategory category;
  final CaseStatus status;
  final CaseUrgency urgency;
  final double progressPercent; // 0.0 to 100.0
  final DateTime? nextHearing;
  final DateTime createdAt;
  final DateTime? closedAt;
  final String? closedBy;
  final String? closeReason;
  final DateTime? withdrawnAt;
  final String? withdrawnBy;
  final List<String> interestedLawyerIds;
  final List<CaseAttachment> attachments;
  final List<LawyerRecommendation> lawyerRecommendations;
  final String? recommendationStatus;
  final DateTime? recommendationGeneratedAt;
  final String? recommendationModel;

  const CaseModel({
    required this.id,
    required this.clientId,
    this.lawyerId,
    required this.title,
    required this.description,
    this.location,
    this.budgetRange,
    required this.category,
    required this.status,
    required this.urgency,
    this.progressPercent = 0,
    this.nextHearing,
    required this.createdAt,
    this.closedAt,
    this.closedBy,
    this.closeReason,
    this.withdrawnAt,
    this.withdrawnBy,
    this.interestedLawyerIds = const [],
    this.attachments = const [],
    this.lawyerRecommendations = const [],
    this.recommendationStatus,
    this.recommendationGeneratedAt,
    this.recommendationModel,
  });

  factory CaseModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Case document ${doc.id} has no data.');
    }

    final normalized = Map<String, dynamic>.from(data);
    normalized.putIfAbsent('id', () => doc.id);

    return CaseModel.fromMap(normalized);
  }

  factory CaseModel.fromMap(Map<String, dynamic> map) {
    return CaseModel(
      id: map['id']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      lawyerId: map['lawyerId'] as String?,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      location: map['location']?.toString(),
      budgetRange: map['budgetRange']?.toString(),
      category: CaseCategory.values.firstWhere(
        (e) => e.name == map['category']?.toString(),
        orElse: () => CaseCategory.other,
      ),
      status: CaseStatus.values.firstWhere(
        (e) => e.name == map['status']?.toString(),
        orElse: () => CaseStatus.pending,
      ),
      urgency: CaseUrgency.values.firstWhere(
        (e) => e.name == map['urgency']?.toString(),
        orElse: () => CaseUrgency.low,
      ),
      progressPercent: (map['progressPercent'] as num?)?.toDouble() ?? 0,
      nextHearing: _readDateTime(map['nextHearing']),
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      closedAt: _readDateTime(map['closedAt']),
      closedBy: map['closedBy']?.toString(),
      closeReason: map['closeReason']?.toString(),
      withdrawnAt: _readDateTime(map['withdrawnAt']),
      withdrawnBy: map['withdrawnBy']?.toString(),
      interestedLawyerIds: List<String>.from(
        map['interestedLawyerIds'] as List? ?? [],
      ),
      attachments: _readAttachments(map['attachments']),
      lawyerRecommendations: _readRecommendations(map['lawyerRecommendations']),
      recommendationStatus: map['recommendationStatus']?.toString(),
      recommendationGeneratedAt: _readDateTime(
        map['recommendationGeneratedAt'],
      ),
      recommendationModel: map['recommendationModel']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'clientId': clientId,
      'lawyerId': lawyerId,
      'title': title,
      'description': description,
      'location': location,
      'budgetRange': budgetRange,
      'category': category.name,
      'status': status.name,
      'urgency': urgency.name,
      'progressPercent': progressPercent,
      'nextHearing': nextHearing == null
          ? null
          : Timestamp.fromDate(nextHearing!),
      'createdAt': Timestamp.fromDate(createdAt),
      if (closedAt != null) 'closedAt': Timestamp.fromDate(closedAt!),
      if (closedBy != null) 'closedBy': closedBy,
      if (closeReason != null) 'closeReason': closeReason,
      if (withdrawnAt != null) 'withdrawnAt': Timestamp.fromDate(withdrawnAt!),
      if (withdrawnBy != null) 'withdrawnBy': withdrawnBy,
      'interestedLawyerIds': interestedLawyerIds,
      'attachments': attachments.map((item) => item.toFirestore()).toList(),
      'lawyerRecommendations': lawyerRecommendations
          .map((item) => item.toFirestore())
          .toList(),
      'recommendationStatus': recommendationStatus,
      if (recommendationGeneratedAt != null)
        'recommendationGeneratedAt': Timestamp.fromDate(
          recommendationGeneratedAt!,
        ),
      'recommendationModel': recommendationModel,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'lawyerId': lawyerId,
      'title': title,
      'description': description,
      'location': location,
      'budgetRange': budgetRange,
      'category': category.name,
      'status': status.name,
      'urgency': urgency.name,
      'progressPercent': progressPercent,
      'nextHearing': nextHearing?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'closedBy': closedBy,
      'closeReason': closeReason,
      'withdrawnAt': withdrawnAt?.toIso8601String(),
      'withdrawnBy': withdrawnBy,
      'interestedLawyerIds': interestedLawyerIds,
      'attachments': attachments.map((item) => item.toMap()).toList(),
      'lawyerRecommendations': lawyerRecommendations
          .map((item) => item.toMap())
          .toList(),
      'recommendationStatus': recommendationStatus,
      'recommendationGeneratedAt': recommendationGeneratedAt?.toIso8601String(),
      'recommendationModel': recommendationModel,
    };
  }

  static List<LawyerRecommendation> _readRecommendations(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<Map>().map((item) {
      return LawyerRecommendation.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  static List<CaseAttachment> _readAttachments(dynamic value) {
    if (value is! List) return const [];

    return value.whereType<Map>().map((item) {
      return CaseAttachment.fromMap(Map<String, dynamic>.from(item));
    }).toList();
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is Timestamp) return value.toDate();

    if (value is String) return DateTime.tryParse(value);

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
      if (seconds is num) {
        final millis =
            seconds.toInt() * 1000 +
            ((nanoseconds is num ? nanoseconds.toInt() : 0) ~/ 1000000);
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    try {
      final dateValue = value.toDate();
      if (dateValue is DateTime) {
        return dateValue;
      }
    } catch (_) {
      // Ignore unsupported timestamp-like values.
    }

    return null;
  }

  String get categoryLabel {
    switch (category) {
      case CaseCategory.property:
        return 'Property';
      case CaseCategory.family:
        return 'Family';
      case CaseCategory.criminal:
        return 'Criminal';
      case CaseCategory.commercial:
        return 'Commercial';
      case CaseCategory.employment:
        return 'Employment';
      case CaseCategory.other:
        return 'Other';
    }
  }

  String get urgencyLabel {
    switch (urgency) {
      case CaseUrgency.high:
        return 'High';
      case CaseUrgency.medium:
        return 'Medium';
      case CaseUrgency.low:
        return 'Low';
    }
  }
}
