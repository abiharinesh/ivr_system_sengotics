import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/stat_card.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';

/// KPI strip above the permit register. Counts come from
/// `GET /api/building-permits/summary` — computing them from the current page
/// would silently under-report as soon as the list is filtered or paged.
class PermitKpiSection extends StatelessWidget {
  final BuildingPermitStats stats;
  final bool isLoading;

  const PermitKpiSection({
    super.key,
    required this.stats,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 4;
        if (width < 600) {
          columns = 1;
        } else if (width < 960) {
          columns = 2;
        }

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 110,
          ),
          children: [
            StatCard(
              title: 'Awaiting action',
              value: '${stats.pendingAction}',
              icon: Icons.pending_actions_rounded,
              gradient: AppTheme.warningGradient,
              isLoading: isLoading,
            ),
            StatCard(
              title: 'Approved permits',
              value: '${stats.approved}',
              icon: Icons.verified_rounded,
              gradient: AppTheme.accentGradient,
              isLoading: isLoading,
            ),
            StatCard(
              title: 'Fees collected',
              value: money.format(stats.feesCollected),
              icon: Icons.account_balance_wallet_rounded,
              gradient: AppTheme.primaryGradient,
              isLoading: isLoading,
            ),
            StatCard(
              title: 'SLA at risk',
              value: '${stats.slaAtRisk}',
              icon: Icons.timer_rounded,
              gradient: AppTheme.errorGradient,
              isLoading: isLoading,
            ),
          ],
        );
      },
    );
  }
}
