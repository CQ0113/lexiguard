import '../models/user_model.dart';
import '../models/case_model.dart';
import '../models/activity_model.dart';

class DummyData {
  /// Simulating Firebase 'users' collection
  static final List<UserModel> users = [
    const UserModel(
      id: 'client_1',
      name: 'Ahmad Razif',
      email: 'ahmad.razif@example.com',
      phone: '+60123456789',
      role: UserRole.client,
    ),
    const UserModel(
      id: 'lawyer_1',
      name: 'Pn. Aishah binti Kamal',
      email: 'aishah.law@example.com',
      phone: '+60198765432',
      role: UserRole.lawyer,
      specialization: 'Property Law',
      hourlyRate: 350.0,
      rating: 4.8,
      yearsExperience: 8,
      barCouncilVerified: true,
      avatarUrl: 'https://i.pravatar.cc/150?img=47',
    ),
    const UserModel(
      id: 'lawyer_2',
      name: 'En. Faizal Ibrahim',
      email: 'faizal.legal@example.com',
      phone: '+60112233445',
      role: UserRole.lawyer,
      specialization: 'Criminal Law',
      hourlyRate: 400.0,
      rating: 4.9,
      yearsExperience: 12,
      barCouncilVerified: true,
      avatarUrl: 'https://i.pravatar.cc/150?img=11',
    ),
  ];

  /// Simulating Firebase 'cases' collection
  static final List<CaseModel> cases = [
    CaseModel(
      id: 'case_1',
      clientId: 'client_1',
      lawyerId: 'lawyer_1', // Currently assigned
      title: 'Property Dispute — Shah Alam',
      description: 'Dispute over land ownership boundaries in Section 13, Shah Alam. Neighbor claims 3 meters of my land.',
      category: CaseCategory.property,
      status: CaseStatus.active,
      urgency: CaseUrgency.high,
      progressPercent: 65.0, // 65% as per Figma
      nextHearing: DateTime.parse('2026-04-15T09:00:00Z'),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      interestedLawyerIds: ['lawyer_1', 'lawyer_2'],
    ),
  ];

  /// Simulating Firebase 'activities' collection for a specific user
  static final List<ActivityModel> userActivities = [
    ActivityModel(
      id: 'act_1',
      title: 'Contract reviewed by AI',
      description: 'Tenancy Agreement — 2 risks found',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: 'document',
    ),
    ActivityModel(
      id: 'act_2',
      title: 'New Lawyer Connection',
      description: 'Pn. Aishah accepted your request.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: 'system',
    ),
  ];
}
