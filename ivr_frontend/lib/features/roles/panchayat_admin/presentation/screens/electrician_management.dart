import 'package:flutter/material.dart';

import 'package:ivr_frontend/features/roles/electrician/presentation/screens/electrician_admin_management_screen.dart';

class PanchayatElectricianManagement extends StatelessWidget {
  const PanchayatElectricianManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return const ElectricianAdminManagementScreen(forSuperAdmin: false);
  }
}
