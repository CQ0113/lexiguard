import 'package:flutter/material.dart';

import '../../models/user_model.dart';
import '../../repositories/vault_document_repository.dart';
import '../client/client_vault_screen.dart';
import '../lawyer/lawyer_vault_screen.dart';

class VaultTabRouterScreen extends StatelessWidget {
  final UserModel user;
  final List<String> defaultSharedLawyerIds;
  final VaultDocumentRepository? repository;

  const VaultTabRouterScreen({
    super.key,
    required this.user,
    this.defaultSharedLawyerIds = const [],
    this.repository,
  });


  @override
  Widget build(BuildContext context) {
    if (user.role == UserRole.client) {
      return ClientVaultScreen(
        userId: user.id,
        sharedLawyerIds: defaultSharedLawyerIds,
        repository: repository,
      );
    }

    return LawyerVaultScreen(
      lawyerUserId: user.id,
      repository: repository,
    );
  }
}
