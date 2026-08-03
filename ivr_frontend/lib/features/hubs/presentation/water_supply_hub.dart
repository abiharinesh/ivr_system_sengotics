import 'package:flutter/material.dart';

import 'package:ivr_frontend/core/widgets/module_hub_scaffold.dart';
import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/infrastructure_approval_screen.dart';
import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/pipeline_grid_screen.dart';
import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/tanks_borewells_screen.dart';
import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/water_flow_logs_screen.dart';

/// Water supply.
///
/// Pipelines, tanks, flow logs and infrastructure approvals were four
/// top-level sidebar entries for one subsystem — a quarter of an engineer's
/// menu spent on sub-views of the same network. One entry, four tabs.
class WaterSupplyHub extends StatelessWidget {
  final int initialIndex;

  const WaterSupplyHub({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return ModuleHubScaffold(
      title: 'Water supply',
      subtitle: 'Pipeline network, storage, flow monitoring and approvals',
      initialIndex: initialIndex,
      tabs: [
        HubTab(
          icon: Icons.grid_on_rounded,
          label: 'Pipeline grid',
          builder: (_) => const PipelineGridScreen(),
        ),
        HubTab(
          icon: Icons.opacity_rounded,
          label: 'Tanks & borewells',
          builder: (_) => const TanksBorewellsScreen(),
        ),
        HubTab(
          icon: Icons.history_edu_rounded,
          label: 'Flow logs',
          builder: (_) => const WaterFlowLogsScreen(),
        ),
        HubTab(
          icon: Icons.approval_rounded,
          label: 'Infra approvals',
          builder: (_) => const InfrastructureApprovalScreen(),
        ),
      ],
    );
  }
}
