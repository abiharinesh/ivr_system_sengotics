import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/dashboard_category_breakdown_card.dart';
import '../../../../core/widgets/dashboard_recent_activity_card.dart';
import '../../../../core/widgets/dashboard_resolution_trend_card.dart';
import '../../../../core/widgets/map_overview.dart';
import '../../../../core/widgets/sa_kpi_card.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/assign_electrician_dialog.dart';
import '../../../../core/models/pole_model.dart';
import '../../../../core/models/stats_model.dart';
import '../../../../core/models/panchayat_model.dart';
import '../../../../core/models/dashboard_insights_model.dart';
import '../../bloc/dashboard_bloc.dart';
import '../../data/models/complaint_model.dart';
import '../../data/super_admin_repository.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SADashBloc, SADashState>(
      builder: (context, state) {
        final isLoading = state is SADashLoading;
        if (state is SADashError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  state.message,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      () => context.read<SADashBloc>().add(LoadSADashboard()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is SADashLoaded || isLoading) {
          return _buildDashboard(
            context,
            state is SADashLoaded ? state : null,
            isLoading: isLoading,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDashboard(BuildContext context, SADashLoaded? state, {bool isLoading = false}) {
    final stats = state?.stats ?? const StatsModel(
      totalComplaints: 0,
      pendingComplaints: 0,
      resolvedComplaints: 0,
      manualReviewComplaints: 0,
      totalPoles: 0,
      totalPanchayats: 0,
      totalAdmins: 0,
    );
    final padding = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0;
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1024;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<SADashBloc>().add(LoadSADashboard());
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state != null && state.warningMessage != null) ...[
                _buildWarningBanner(context),
                const SizedBox(height: 16),
              ],

              // Header Row
              _buildHeaderRow(context),
              const SizedBox(height: 24),

              // KPI Cards Grid
              _buildKpiGrid(context, stats, state, isLoading: isLoading),
              const SizedBox(height: 24),

              // Bento Grid Layout
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildComplaintQueue(context, state?.recentComplaints ?? const [], isLoading: isLoading),
                          const SizedBox(height: 24),
                          DashboardResolutionTrendCard(
                            trend: state?.insights.resolutionTrend ?? const ResolutionTrend(currentWeek: [], lastWeek: []),
                            isLoading: isLoading,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildQuickActions(context),
                          const SizedBox(height: 24),
                          _buildPanchayatOverview(context, state?.panchayats ?? const [], isLoading: isLoading),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildComplaintQueue(context, state?.recentComplaints ?? const [], isLoading: isLoading),
                    const SizedBox(height: 24),
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    DashboardResolutionTrendCard(
                      trend: state?.insights.resolutionTrend ?? const ResolutionTrend(currentWeek: [], lastWeek: []),
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 24),
                    _buildPanchayatOverview(context, state?.panchayats ?? const [], isLoading: isLoading),
                  ],
                ),

              const SizedBox(height: 24),

              // Bottom Row: Category Breakdown + Recent Activity
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildGisQuickView(context, state?.poles ?? const [], isLoading: isLoading),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 1,
                      child: DashboardCategoryBreakdownCard(
                        categories: state?.insights.byCategory ?? const [],
                        isLoading: isLoading,
                      ),
                    ),
                  ],
                )
              else ...[
                _buildGisQuickView(context, state?.poles ?? const [], isLoading: isLoading),
                const SizedBox(height: 24),
                DashboardCategoryBreakdownCard(
                  categories: state?.insights.byCategory ?? const [],
                  isLoading: isLoading,
                ),
              ],

              const SizedBox(height: 24),

              // Recent Activity
              DashboardRecentActivityCard(
                items: state?.insights.recentActivity ?? const [],
                onViewAll: () => context.go('/complaints'),
                isLoading: isLoading,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Warning Banner ──────────────────────────────────────────────────────
  Widget _buildWarningBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppTheme.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Some dashboard data is temporarily unavailable. Pull to refresh.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => context.read<SADashBloc>().add(LoadSADashboard()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── Header Row ──────────────────────────────────────────────────────────
  Widget _buildHeaderRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'System',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              'SuperAdmin',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 850;
            final headerWidgets = [
              Text(
                'System Overview',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Metropolis',
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (isMobile) const SizedBox(height: 12) else const Spacer(),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('System-wide broadcast alert sent!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
                    icon: const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Broadcast Alert'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/analytics'),
                    icon: const Icon(Icons.bar_chart_rounded, size: 18),
                    label: const Text('Analytics'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ],
              ),
            ];

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: headerWidgets,
              );
            }
            return Row(
              children: headerWidgets,
            );
          },
        ),
      ],
    );
  }

  // ── KPI Cards Grid ──────────────────────────────────────────────────────
  Widget _buildKpiGrid(BuildContext context, StatsModel stats, SADashLoaded? state, {bool isLoading = false}) {
    final resolutionRate = stats.totalComplaints > 0
        ? (stats.resolvedComplaints / stats.totalComplaints * 100).round()
        : 0;

    final faultPoles = ((stats.totalPoles ?? 0) - (stats.totalPoles ?? 0) * 0.82).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = w > 1100 ? 4 : (w > 600 ? 2 : 1);
        final ratio = w > 1100 ? 1.7 : (w > 600 ? 1.9 : (w < 350 ? 1.45 : 2.2));

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: ratio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Card 1: Total Complaints
            SAKpiCard(
              title: 'Total Complaints',
              value: stats.totalComplaints.toString(),
              icon: Icons.report_problem_rounded,
              iconBg: AppTheme.error.withValues(alpha: 0.1),
              iconColor: AppTheme.error,
              trendWidget: Row(
                children: [
                  const Icon(Icons.trending_up_rounded, size: 14, color: AppTheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${stats.pendingComplaints} pending',
                      style: const TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              isLoading: isLoading,
              onTap: () => context.go('/complaints'),
            ),

            // Card 2: Total Panchayats
            SAKpiCard(
              title: 'Total Panchayats',
              value: (stats.totalPanchayats ?? 0).toString(),
              icon: Icons.location_city_rounded,
              iconBg: AppTheme.primary.withValues(alpha: 0.1),
              iconColor: AppTheme.primary,
              trendWidget: Row(
                children: [
                  Icon(Icons.people_outline_rounded, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${stats.totalAdmins ?? 0} admins active',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              isLoading: isLoading,
              onTap: () => context.go('/panchayats'),
            ),

            // Card 3: Resolution Rate
            SAKpiCard(
              title: 'Resolution Rate',
              value: '$resolutionRate%',
              icon: Icons.check_circle_rounded,
              iconBg: AppTheme.accent.withValues(alpha: 0.1),
              iconColor: AppTheme.accent,
              trendWidget: Container(
                margin: const EdgeInsets.only(top: 8),
                width: double.infinity,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (resolutionRate / 100).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              isLoading: isLoading,
            ),

            // Card 4: Active Infrastructure
            SAKpiCard(
              title: 'Active Infrastructure',
              value: (stats.totalPoles ?? 0).toString(),
              icon: Icons.electrical_services_rounded,
              iconBg: AppTheme.warning.withValues(alpha: 0.1),
              iconColor: AppTheme.warning,
              trendWidget: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppTheme.warning),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$faultPoles critical faults',
                      style: const TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              isLoading: isLoading,
              onTap: () => context.go('/poles'),
            ),
          ],
        );
      },
    );
  }

  // ── Complaint Queue ─────────────────────────────────────────────────────
  Widget _buildComplaintQueue(BuildContext context, List<ComplaintModel> complaints, {bool isLoading = false}) {
    return Container(
      height: 500,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Complaint Queue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Metropolis',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AI-processed voice complaints across all panchayats',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    isLoading ? 'Pending: ...' : 'Pending: ${complaints.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isLoading
                ? const AppLoadingState(
                    message: 'Loading complaints...',
                    style: AppLoadingStyle.list,
                  )
                : (complaints.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, size: 40, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                'All Clean! No Pending Complaints',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All complaints across panchayats have been addressed.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: complaints.length.clamp(0, 5),
                        itemBuilder: (context, index) {
                          final complaint = complaints[index];
                          return _SAComplaintQueueItem(complaint: complaint);
                        },
                      )),
          ),
          const Divider(height: 1),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go('/complaints'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
              child: Text(
                'View All Complaints',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── GIS Quick View ──────────────────────────────────────────────────────
  Widget _buildGisQuickView(BuildContext context, List<PoleModel> poles, {bool isLoading = false}) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Infrastructure Map (GIS View)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Metropolis',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time status across all panchayats',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  isLoading ? '... assets tracked' : '${poles.length} assets tracked',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  if (isLoading)
                    const AppShimmer.rectangular(
                      width: double.infinity,
                      height: double.infinity,
                    )
                  else
                    MapOverview(
                      poles: poles,
                      height: 400,
                      showLegend: false,
                      showCardDecoration: false,
                      borderRadius: 12,
                      showInfoWindow: true,
                      focusFaultPolesFirst: true,
                      usePngMarkers: true,
                    ),
                  if (!isLoading)
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: AppTheme.softShadow,
                          border: Border.all(color: AppTheme.stroke.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ASSET STATUS',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _GisLegendRow(label: 'Active (Healthy)', color: AppTheme.accent),
                            const SizedBox(height: 6),
                            const _GisLegendRow(label: 'Maintenance Due', color: AppTheme.warning),
                            const SizedBox(height: 6),
                            const _GisLegendRow(label: 'Critical Fault', color: AppTheme.error),
                            const SizedBox(height: 6),
                            _GisLegendRow(label: 'Water Pipelines', color: AppTheme.primary),
                            const SizedBox(height: 6),
                            const _GisLegendRow(label: 'Water Taps', color: Colors.cyan),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ───────────────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Metropolis',
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),
          _QuickActionButton(
            label: 'Manage Panchayats',
            icon: Icons.location_city_rounded,
            onTap: () => context.go('/panchayats'),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: 'User Management',
            icon: Icons.people_outline_rounded,
            onTap: () => context.go('/users'),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: 'AI Settings',
            icon: Icons.psychology_rounded,
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: 'IVR Call Logs',
            icon: Icons.phone_in_talk_rounded,
            onTap: () => context.go('/voice-calls'),
          ),
        ],
      ),
    );
  }

  // ── Panchayat Overview ──────────────────────────────────────────────────
  Widget _buildPanchayatOverview(BuildContext context, List<PanchayatModel> panchayats, {bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Panchayat Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Metropolis',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active panchayat status',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isLoading ? '...' : '${panchayats.length} Active',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: AppLoadingState(
                message: 'Loading panchayats...',
                style: AppLoadingStyle.list,
              ),
            )
          else if (panchayats.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No panchayats registered yet.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: panchayats.length.clamp(0, 5),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final panch = panchayats[index];
                return InkWell(
                  onTap: () => context.go('/panchayats'),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.stroke.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.location_city_rounded, color: AppTheme.primary, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                panch.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${panch.polesCount} poles • ${panch.complaintsCount} complaints • ${panch.usersCount} users',
                                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
                      ],
                    ),
                  ),
                );
              },
            ),
          const Divider(height: 1),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go('/panchayats'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
              child: Text(
                'Manage All Panchayats',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }
}

class _GisLegendRow extends StatelessWidget {
  final String label;
  final Color color;

  const _GisLegendRow({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SAComplaintQueueItem extends StatefulWidget {
  final ComplaintModel complaint;
  const _SAComplaintQueueItem({required this.complaint});

  @override
  State<_SAComplaintQueueItem> createState() => _SAComplaintQueueItemState();
}

class _SAComplaintQueueItemState extends State<_SAComplaintQueueItem> {
  bool _assigning = false;

  String _getTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return DateFormat('MMM d, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final complaint = widget.complaint;
    final timeStr = _getTimeAgo(complaint.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/complaints'),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic, color: AppTheme.error, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${complaint.complaintType ?? 'Voice Complaint'} - ${complaint.panchayat?.name ?? 'Unknown Panchayat'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$timeStr • ID: #${complaint.id} • Pole ${complaint.pole?.poleNumber ?? '#${complaint.pole?.id ?? 'N/A'}'}',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_assigning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _handleAssign(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Assign',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTwoCol = constraints.maxWidth > 500;
                  final originalText = complaint.voiceCall?.transcript ??
                      complaint.description ??
                      'Voice complaint received via IVR.';
                  final translationText = complaint.voiceCall?.transcriptEnglish ??
                      complaint.description ??
                      'Voice complaint received via IVR.';

                  final leftWidget = Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.translate, size: 12, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              'ORIGINAL TRANSCRIPT',
                              style: TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          originalText,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );

                  final rightWidget = Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 12, color: AppTheme.accent),
                            const SizedBox(width: 4),
                            Text(
                              'AI ENGLISH TRANSLATION',
                              style: TextStyle(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          translationText,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.accent,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );

                  if (isTwoCol) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: leftWidget),
                        const SizedBox(width: 12),
                        Expanded(child: rightWidget),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      leftWidget,
                      const SizedBox(height: 8),
                      rightWidget,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAssign(BuildContext context) async {
    final complaint = widget.complaint;
    setState(() => _assigning = true);

    try {
      final id = await showAssignElectricianDialog(
        context: context,
        complaint: complaint,
        isSuperAdmin: true,
      );

      if (id != null && context.mounted) {
        await SuperAdminRepository().assignElectrician(complaint.id, id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Electrician assigned successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.read<SADashBloc>().add(LoadSADashboard());
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }
}