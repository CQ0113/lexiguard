import 'package:cloud_firestore/cloud_firestore.dart';

// Case Model — ready for Firebase Firestore
// Collection path: 'cases'

enum CaseStatus { active, pending, closed }

enum CaseUrgency { low, medium, high }

enum CaseCategory { property, family, criminal, commercial, employment, other }

class CaseModel {
  final String id;
  final String clientId;
  final String? lawyerId;
  final String title;
  final String description;
  final CaseCategory category;
  final CaseStatus status;
  final CaseUrgency urgency;
  final double progressPercent; // 0.0 to 100.0
  final DateTime? nextHearing;
  final DateTime createdAt;
  final List<String> interestedLawyerIds;

  const CaseModel({
    required this.id,
    required this.clientId,
    this.lawyerId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.urgency,
    this.progressPercent = 0,
    this.nextHearing,
    required this.createdAt,
    this.interestedLawyerIds = const [],
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
      interestedLawyerIds: List<String>.from(
        map['interestedLawyerIds'] as List? ?? [],
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'clientId': clientId,
      'lawyerId': lawyerId,
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
      'urgency': urgency.name,
      'progressPercent': progressPercent,
      'nextHearing': nextHearing == null
          ? null
          : Timestamp.fromDate(nextHearing!),
      'createdAt': Timestamp.fromDate(createdAt),
      'interestedLawyerIds': interestedLawyerIds,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'lawyerId': lawyerId,
      'title': title,
      'description': description,
      'category': category.name,
      'status': status.name,
      'urgency': urgency.name,
      'progressPercent': progressPercent,
      'nextHearing': nextHearing?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'interestedLawyerIds': interestedLawyerIds,
    };
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
