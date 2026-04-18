import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { client, lawyer }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final DateTime? createdAt;

  // Lawyer-specific fields
  final String? barNumber;
  final String? specialization;
  final double? hourlyRate;
  final double? rating;
  final int? yearsExperience;
  final bool? barCouncilVerified;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.createdAt,
    // Lawyer fields
    this.barNumber,
    this.specialization,
    this.hourlyRate,
    this.rating,
    this.yearsExperience,
    this.barCouncilVerified,
  });

  // ─── Firestore Deserialization ───────────────────────────────────────────────

  factory UserModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: data['role'] == 'lawyer' ? UserRole.lawyer : UserRole.client,
      avatarUrl: data['avatarUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      barNumber: data['barNumber'] as String?,
      specialization: data['specialization'] as String?,
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      rating: (data['rating'] as num?)?.toDouble(),
      yearsExperience: data['yearsExperience'] as int?,
      barCouncilVerified: data['barCouncilVerified'] as bool?,
    );
  }

  // ─── Firestore Serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role == UserRole.lawyer ? 'lawyer' : 'client',
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
      // Lawyer-only fields (only written if non-null)
      if (barNumber != null) 'barNumber': barNumber,
      if (specialization != null) 'specialization': specialization,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      if (yearsExperience != null) 'yearsExperience': yearsExperience,
      if (barCouncilVerified != null)
        'barCouncilVerified': barCouncilVerified,
    };
  }

  // ─── Legacy Map (kept for DummyData compatibility) ───────────────────────────

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      role: map['role'] == 'lawyer' ? UserRole.lawyer : UserRole.client,
      avatarUrl: map['avatarUrl'] as String?,
      barNumber: map['barNumber'] as String?,
      specialization: map['specialization'] as String?,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble(),
      yearsExperience: map['yearsExperience'] as int?,
      barCouncilVerified: map['barCouncilVerified'] as bool?,
    );
  }
}
