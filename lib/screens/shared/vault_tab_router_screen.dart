import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../client/client_vault_screen.dart';
import '../lawyer/lawyer_vault_screen.dart';

class VaultTabRouterScreen extends StatelessWidget {
  final UserModel user;
  final List<String> defaultSharedLawyerIds;

  const VaultTabRouterScreen({
    super.key,
    required this.user,
    this.defaultSharedLawyerIds = const [],
  });


  @override
  Widget build(BuildContext context) {
    if (user.role == UserRole.client) {
      return ClientVaultScreen(
        userId: user.id,
        sharedLawyerIds: defaultSharedLawyerIds,
      );
    }

    return LawyerVaultScreen(lawyerUserId: user.id);
  }
}
