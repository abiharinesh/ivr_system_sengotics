import 'package:flutter/material.dart';

import '../../electrician/presentation/electrician_admin_management_screen.dart';

class SuperAdminElectricianManagement extends StatelessWidget {
  const SuperAdminElectricianManagement({super.key});

  @override
  Widget build(BuildContext context) {
    return const ElectricianAdminManagementScreen(forSuperAdmin: true);
  }
}
