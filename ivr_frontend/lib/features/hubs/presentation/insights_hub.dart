import 'package:flutter/material.dart';

import 'package:ivr_frontend/core/widgets/module_hub_scaffold.dart';
import 'package:ivr_frontend/features/modules/reports/presentation/report_generation_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/analytics_screen.dart';
import 'package:ivr_frontend/features/modules/complaints/presentation/sla_analytics_screen.dart';

/// Reporting and analytics.
///
/// Three sidebar entries — "Report Generation", "Analytics" and "SLA
/// Analytics" — were three ways of asking the same question. One entry, three
/// tabs.
class InsightsHub extends StatelessWidget {
  final int initialIndex;

  const InsightsHub({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return ModuleHubScaffold(
      title: 'Reports & analytics',
      subtitle: 'Generated reports, operational analytics and SLA performance',
      initialIndex: initialIndex,
      tabs: [
        HubTab(
          icon: Icons.insights_rounded,
          label: 'Analytics',
          builder: (_) => const AnalyticsScreen(),
        ),
        HubTab(
          icon: Icons.timer_rounded,
          label: 'SLA performance',
          builder: (_) => const SlaAnalyticsScreen(),
        ),
        HubTab(
          icon: Icons.document_scanner_rounded,
          label: 'Report generation',
          builder: (_) => const ReportGenerationScreen(),
        ),
      ],
    );
  }
}
