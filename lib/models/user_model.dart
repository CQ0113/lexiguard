// User Model — ready to swap to Firebase Firestore
// Replace DummyData references with FirebaseFirestore.instance.collection('users')

enum UserRole { client, lawyer }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;

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
    // Lawyer fields
    this.barNumber,
    this.specialization,
    this.hourlyRate,
    this.rating,
    this.yearsExperience,
    this.barCouncilVerified,
  });

  // Convert from Firestore document — replace with:
  // factory UserModel.fromFirestore(DocumentSnapshot doc) {
  //   final data = doc.data()! as Map<String, dynamic>;
  //   return UserModel(id: doc.id, ...);
  // }
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

  // Convert to Firestore document — replace with:
  // Future<void> save() => FirebaseFirestore.instance.collection('users').doc(id).set(toMap());
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role == UserRole.lawyer ? 'lawyer' : 'client',
      'avatarUrl': avatarUrl,
      'barNumber': barNumber,
      'specialization': specialization,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'yearsExperience': yearsExperience,
      'barCouncilVerified': barCouncilVerified,
    };
  }
}
