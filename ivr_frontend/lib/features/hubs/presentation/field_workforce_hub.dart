import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ivr_frontend/core/widgets/module_hub_scaffold.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/panchayat_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/user_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/agent_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/electrician_management.dart'
    as sa;
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/plumber_management.dart'
    as sa;
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/electrician_management.dart'
    as pa;
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/plumber_management.dart'
    as pa;

/// Field workforce — electricians, plumbers and survey agents in one place.
///
/// These were three top-level sidebar entries pointing at three near-identical
/// management screens. They are the same job — assigning and tracking field
/// staff — so they are now three tabs behind one entry.
class FieldWorkforceHub extends StatelessWidget {
  final bool isSuperAdmin;
  final int initialIndex;

  const FieldWorkforceHub({
    super.key,
    required this.isSuperAdmin,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ModuleHubScaffold(
      title: 'Field workforce',
      subtitle: 'Electricians, plumbers and survey agents',
      initialIndex: initialIndex,
      tabs: [
        HubTab(
          icon: Icons.electrical_services_rounded,
          label: 'Electricians',
          builder: (_) => isSuperAdmin
              ? const sa.SuperAdminElectricianManagement()
              : const pa.PanchayatElectricianManagement(),
        ),
        HubTab(
          icon: Icons.plumbing_rounded,
          label: 'Plumbers',
          builder: (_) => isSuperAdmin
              ? const sa.SuperAdminPlumberManagement()
              : const pa.PanchayatPlumberManagement(),
        ),
        HubTab(
          icon: Icons.group_rounded,
          label: 'Survey agents',
          // Agent management owns two blocs; scoping them to the tab means an
          // unopened tab never fires their loads.
          builder: (_) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => UserMgmtBloc()..add(LoadUsers())),
              BlocProvider(
                create: (_) => PanchayatBloc()..add(LoadPanchayats()),
              ),
            ],
            child: const AgentManagement(),
          ),
        ),
      ],
    );
  }
}
