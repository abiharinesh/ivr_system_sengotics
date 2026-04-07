import 'package:flutter/material.dart';

import 'user_management.dart';

class AgentManagement extends StatelessWidget {
  const AgentManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserManagement(
      initialRoleFilter: 'agent',
      lockRoleFilter: true,
      customTitle: 'Agent Management',
      customSubtitle: 'Create and manage field agents',
    );
  }
}
