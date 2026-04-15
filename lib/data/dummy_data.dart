import '../models/user_model.dart';
import '../models/case_model.dart';
import '../models/activity_model.dart';

class DummyData {
  // ── Users ────────────────────────────────────────────────────────────────
  static final List<UserModel> users = [
    const UserModel(
      id: 'client_1',
      name: 'Ahmad Razif',
      email: 'ahmad.razif@example.com',
      phone: '+60123456789',
      role: UserRole.client,
    ),
    const UserModel(
      id: 'client_2',
      name: 'Nurul Hana Binti Aziz',
      email: 'nurul.hana@example.com',
      phone: '+60167891234',
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
      barNumber: 'B/MY/09384',
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
      barNumber: 'B/MY/07251',
      avatarUrl: 'https://i.pravatar.cc/150?img=11',
    ),
  ];

  // ── Cases assigned to a lawyer ───────────────────────────────────────────
  static final List<CaseModel> cases = [
    CaseModel(
      id: 'case_1',
      clientId: 'client_1',
      lawyerId: 'lawyer_1',
      title: 'Property Dispute — Shah Alam',
      description:
          'Dispute over land ownership boundaries in Section 13, Shah Alam. '
          'Neighbor claims 3 metres of my land.',
      category: CaseCategory.property,
      status: CaseStatus.active,
      urgency: CaseUrgency.high,
      progressPercent: 65.0,
      nextHearing: DateTime.parse('2026-04-15T09:00:00Z'),
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      interestedLawyerIds: ['lawyer_1', 'lawyer_2'],
    ),
    CaseModel(
      id: 'case_2',
      clientId: 'client_2',
      lawyerId: 'lawyer_1',
      title: 'Tenancy Agreement Dispute — Petaling Jaya',
      description:
          'Landlord refusing to return security deposit after end of tenancy. '
          'Client has evidence of full payment.',
      category: CaseCategory.property,
      status: CaseStatus.active,
      urgency: CaseUrgency.medium,
      progressPercent: 30.0,
      nextHearing: DateTime.parse('2026-04-22T10:00:00Z'),
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      interestedLawyerIds: ['lawyer_1'],
    ),
  ];

  // ── Open cases (no lawyer assigned yet) ─────────────────────────────────
  static List<CaseModel> openCases = [
    CaseModel(
      id: 'case_open_1',
      clientId: 'client_1',
      lawyerId: null,
      title: 'Employment Termination — Kuala Lumpur',
      description:
          'Client was terminated without cause after 5 years of service. '
          'Seeking legal representation for wrongful dismissal claim.',
      category: CaseCategory.employment,
      status: CaseStatus.pending,
      urgency: CaseUrgency.high,
      progressPercent: 0.0,
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      interestedLawyerIds: [],
    ),
    CaseModel(
      id: 'case_open_2',
      clientId: 'client_2',
      lawyerId: null,
      title: 'Commercial Contract Breach — Cyberjaya',
      description:
          'Software vendor failed to deliver agreed product within timeline, '
          'causing business losses of RM 80,000.',
      category: CaseCategory.commercial,
      status: CaseStatus.pending,
      urgency: CaseUrgency.medium,
      progressPercent: 0.0,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      interestedLawyerIds: [],
    ),
    CaseModel(
      id: 'case_open_3',
      clientId: 'client_1',
      lawyerId: null,
      title: 'Family — Divorce & Asset Division',
      description:
          'Amicable divorce filing with joint custody of 2 children. '
          'Needs legal assistance for court submission.',
      category: CaseCategory.family,
      status: CaseStatus.pending,
      urgency: CaseUrgency.low,
      progressPercent: 0.0,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      interestedLawyerIds: [],
    ),
  ];

  // ── Client activities ────────────────────────────────────────────────────
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

  // ── Lawyer-specific activities ───────────────────────────────────────────
  static final List<ActivityModel> lawyerActivities = [
    ActivityModel(
      id: 'lact_1',
      title: 'Hearing Reminder',
      description: 'Property Dispute — Shah Alam  •  9:00 AM today',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      type: 'hearing',
    ),
    ActivityModel(
      id: 'lact_2',
      title: 'Document Signed',
      description: 'Ahmad Razif signed the retainer agreement.',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      type: 'document',
    ),
    ActivityModel(
      id: 'lact_3',
      title: 'New Message',
      description: 'Client Nurul Hana sent a message about the PJ case.',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      type: 'message',
    ),
    ActivityModel(
      id: 'lact_4',
      title: 'Payment Received',
      description: 'RM 350 retainer fee received from Ahmad Razif.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: 'payment',
    ),
  ];
}
