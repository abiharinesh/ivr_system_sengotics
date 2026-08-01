import 'package:flutter/material.dart';

import 'package:ivr_frontend/features/roles/plumber/presentation/screens/plumber_admin_management_screen.dart';

class SuperAdminPlumberManagement extends StatelessWidget {
  const SuperAdminPlumberManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlumberAdminManagementScreen(forSuperAdmin: true);
  }
}
