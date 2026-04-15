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

  /// Replace with fromFirestore
  factory CaseModel.fromMap(Map<String, dynamic> map) {
    return CaseModel(
      id: map['id'] as String,
      clientId: map['clientId'] as String,
      lawyerId: map['lawyerId'] as String?,
      title: map['title'] as String,
      description: map['description'] as String,
      category: CaseCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => CaseCategory.other,
      ),
      status: CaseStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CaseStatus.pending,
      ),
      urgency: CaseUrgency.values.firstWhere(
        (e) => e.name == map['urgency'],
        orElse: () => CaseUrgency.low,
      ),
      progressPercent: (map['progressPercent'] as num?)?.toDouble() ?? 0,
      nextHearing: map['nextHearing'] != null
          ? DateTime.parse(map['nextHearing'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      interestedLawyerIds:
          List<String>.from(map['interestedLawyerIds'] as List? ?? []),
    );
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

  String get categoryLabel {
    switch (category) {
      case CaseCategory.property: return 'Property';
      case CaseCategory.family: return 'Family';
      case CaseCategory.criminal: return 'Criminal';
      case CaseCategory.commercial: return 'Commercial';
      case CaseCategory.employment: return 'Employment';
      case CaseCategory.other: return 'Other';
    }
  }

  String get urgencyLabel {
    switch (urgency) {
      case CaseUrgency.high: return 'High';
      case CaseUrgency.medium: return 'Medium';
      case CaseUrgency.low: return 'Low';
    }
  }
}
