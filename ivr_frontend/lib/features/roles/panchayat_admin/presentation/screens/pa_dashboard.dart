import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/map_overview.dart';
import 'package:ivr_frontend/core/widgets/assign_electrician_dialog.dart';
import 'package:ivr_frontend/core/models/pole_model.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/complaint_model.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_event.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/bloc/pa_dashboard_bloc.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/data/panchayat_admin_repository.dart';
import 'package:ivr_frontend/core/models/stats_model.dart';
import 'package:ivr_frontend/core/widgets/app_shimmer.dart';

class PADashboard extends StatelessWidget {
  const PADashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PADashBloc, PADashState>(
      listener: (context, state) {
        if (state is PADashLoaded) {
          context.read<AuthBloc>().add(UpdateAuthUser(state.profile));
        }
      },
      builder: (context, state) {
        final isLoading = state is PADashLoading;
        if (state is PADashError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  state.message,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.read<PADashBloc>().add(LoadPADashboard()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is PADashLoaded || isLoading) {
          return _buildContent(
            context,
            state is PADashLoaded ? state : null,
            isLoading: isLoading,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildContent(BuildContext context, PADashLoaded? state, {bool isLoading = false}) {
    final stats = state?.stats ?? const StatsModel(
      totalComplaints: 0,
      pendingComplaints: 0,
      resolvedComplaints: 0,
      manualReviewComplaints: 0,
      totalPoles: 0,
      totalPanchayats: 0,
      totalAdmins: 0,
    );
    final profile = state?.profile;
    final titlePanchayat = profile?.panchayatName ?? (isLoading ? 'Loading Panchayat...' : 'Panchayat Portal');
    final padding = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0;
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w >= 1024;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<PADashBloc>().add(LoadPADashboard());
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
              
              // Breadcrumbs & Title & Actions Row
              _buildHeaderRow(context, titlePanchayat),
              const SizedBox(height: 24),

              // KPI Cards Grid
              _buildKpiGrid(context, stats, state?.electricians.length ?? 0, isLoading: isLoading),
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
                          _buildComplaintQueue(context, state?.complaints ?? const [], isLoading: isLoading),
                          const SizedBox(height: 24),
                          _buildGisQuickView(context, state?.poles ?? const [], titlePanchayat, isLoading: isLoading),
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
                          _buildFieldAgents(context, state?.electricians ?? const [], isLoading: isLoading),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildComplaintQueue(context, state?.complaints ?? const [], isLoading: isLoading),
                    const SizedBox(height: 24),
                    _buildGisQuickView(context, state?.poles ?? const [], titlePanchayat, isLoading: isLoading),
                    const SizedBox(height: 24),
                    _buildQuickActions(context),
                    const SizedBox(height: 24),
                    _buildFieldAgents(context, state?.electricians ?? const [], isLoading: isLoading),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildEmergencyFab(context),
    );
  }

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
            onPressed: () => context.read<PADashBloc>().add(LoadPADashboard()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, String panchayatName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Panchayats',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                panchayatName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                'Admin Overview',
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
                    onPressed: () => context.go('/panchayat-admin/profile'),
                    icon: const Icon(Icons.account_circle_outlined, size: 18),
                    label: const Text('Admin Profile'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('WhatsApp Broadcast Alert Broadcasted successfully!'),
                          backgroundColor: Colors.teal,
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Broadcast WhatsApp Alert'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/tenders/new'),
                    icon: const Icon(Icons.assignment_add, size: 18),
                    label: const Text('Initiate Tender'),
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

  Widget _buildKpiGrid(BuildContext context, dynamic stats, int activeStaffCount, {bool isLoading = false}) {
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
            // Card 1: Pending Complaints
            _KpiCard(
              title: 'Pending Complaints',
              value: stats.pendingComplaints.toString(),
              icon: Icons.warning_amber_rounded,
              iconBg: AppTheme.error.withValues(alpha: 0.1),
              iconColor: AppTheme.error,
              trendWidget: const Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 14, color: AppTheme.error),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '+12% this week',
                      style: TextStyle(fontSize: 11, color: AppTheme.error, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              isLoading: isLoading,
            ),
            // Card 2: Field Staff Active
            _KpiCard(
              title: 'Field Staff Active',
              value: activeStaffCount.toString(),
              icon: Icons.engineering_outlined,
              iconBg: AppTheme.accent.withValues(alpha: 0.1),
              iconColor: AppTheme.accent,
              trendWidget: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Electricians and Plumbers',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              isLoading: isLoading,
            ),
            // Card 3: Water Tank Levels
            _KpiCard(
              title: 'Water Tank Levels',
              value: '78%',
              icon: Icons.water_drop_outlined,
              iconBg: AppTheme.info.withValues(alpha: 0.1),
              iconColor: AppTheme.info,
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
                  widthFactor: 0.78,
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
            // Card 4: Live Tenders
            _KpiCard(
              title: 'Live Tenders',
              value: '06',
              icon: Icons.gavel_rounded,
              iconBg: AppTheme.primary.withValues(alpha: 0.1),
              iconColor: AppTheme.primary,
              trendWidget: Row(
                children: [
                  Icon(Icons.event_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '2 closing tomorrow',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              isLoading: isLoading,
            ),
          ],
        );
      },
    );
  }

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
                        'Complaint Queue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Metropolis',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Prioritized AI-processed voice reports',
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
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    isLoading ? 'New: ...' : 'New: ${complaints.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
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
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: complaints.length,
                        itemBuilder: (context, index) {
                          final complaint = complaints[index];
                          return _ComplaintQueueItem(complaint: complaint);
                        },
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildGisQuickView(BuildContext context, List<PoleModel> poles, String panchayatName, {bool isLoading = false}) {
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
                        'Panchayat Asset Map (GIS View)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Metropolis',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Real-time status in $panchayatName',
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
                            _GisLegendRow(label: 'Normal (142)', color: AppTheme.accent),
                            const SizedBox(height: 6),
                            const _GisLegendRow(label: 'Faulty (08)', color: AppTheme.error),
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
            label: 'Universal Search',
            icon: Icons.search_rounded,
            onTap: () => context.go('/search'),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: 'Contractors',
            icon: Icons.engineering_rounded,
            onTap: () => context.go('/contractors'),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: 'Field Inspections',
            icon: Icons.checklist_rtl_rounded,
            onTap: () => context.go('/inspections'),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: 'Citizen Portal',
            icon: Icons.campaign_rounded,
            onTap: () => context.go('/citizen-portal'),
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: 'Municipality Modules',
            icon: Icons.account_balance_rounded,
            onTap: () => context.go('/municipality'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldAgents(BuildContext context, List<dynamic> electricians, {bool isLoading = false}) {
    // Alternate South Indian avatars for our technicians
    final avatars = [
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCd58xCiZtMtZFm0REuU33Ma_eEETeY3nqHynP6Homm4ieVzDLSnDiwFfxkrTdQ8KtWN8MPFuBoxH5x-agic26diOCj3GUQNKntTeK9i0g860lD5rYJgFPs7ZC08RuC_ugjlPjxgiJNMvRn0W_i1Nym1ljyJOUDj57shwS_RELTj3aNqg-9koHxkmSzXdYjGuk9CNkLXQm4iV0CdmB6A5FJFA-bMv1p5H6qKY1La3u3W41sHVcnidODeTAvqRAK6rYl8zt1k-ERc8s',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCNB_qumltzl6mjNBCIeYSb-jDDbyM3RAihHPLGvm_VPOle6h0D0qbh7z4ZFUqYDM-_PFFdikYq03o83OURW6Dkuo_R9pySugE5bVa0NCVfiYwYm30AaEpyvGQ7FF28GbyA3QRBAgEeiBiU61Fi8PQT_215dIP61Ayu6HtwMrBjlzgfcG5BLBrJS6S4YpMGnpb4NSHeFm_eWvpvzpMz83TlvzWaYhPvU7H4Seln1dnaIOGqVaxBJfpl_q0jmxLPPVh0PkiuqyDrf2Q',
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB_Sdb8IHZ0LgGHLMIIUwMyiAfJ8AEX1NeyG7q-TGDd_mGASUZrzOXPkdXnWQ_otYwMD0V2WKWFB8OSNXE-W_-l7kPOV75SiZPzXUGHDBAgR4Jsz_9P-1uM1xC6xBc-qiHNekxS8-rf-A9_7NVB85X5Rg0FTi_aKZMpfFQT2bHNaXv5ZdhTAdNnADgqJcPvWyUZfdLsc5QKFTUMMbc6g-y6MbUTR6WY3TnqHEwuPLw5bKtJZFWNH_eIJYN0AIGx6T-rtqBfnsEuc60'
    ];

    // Mock active count as the number of electricians, or show hardcoded/loaded
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
                        'Field Agents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Metropolis',
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Active local responders',
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
                    isLoading ? '... Active' : '${electricians.length} Active',
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
                message: 'Loading agents...',
                style: AppLoadingStyle.list,
              ),
            )
          else if (electricians.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No field agents registered yet.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: electricians.length.clamp(0, 3), // Show top 3
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final agent = Map<String, dynamic>.from(electricians[index] as Map);
                final email = agent['email']?.toString() ?? 'Agent';
                final isOffline = index == 2; // Mock Vikram as offline per mockup design
                final avatarUrl = avatars[index % avatars.length];

                return Opacity(
                  opacity: isOffline ? 0.55 : 1.0,
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(avatarUrl),
                            backgroundColor: AppTheme.bgSurface,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isOffline ? AppTheme.textMuted : AppTheme.accent,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.bgCard, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email.split('@').first,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              isOffline ? 'Technician • Offline' : 'Electrician • Ward ${index + 1}',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOffline
                              ? AppTheme.stroke
                              : AppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOffline ? 'OFFLINE' : 'ON DUTY',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isOffline ? AppTheme.textMuted : AppTheme.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const Divider(height: 1),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.go('/admin/electricians'),
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
                'View All Personnel',
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

  Widget _buildEmergencyFab(BuildContext context) {
    return Tooltip(
      message: 'Emergency Dispatch',
      child: FloatingActionButton.large(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency Dispatch initiated! Broadcast notifications sent to nearest active field agents.'),
              backgroundColor: Colors.red,
            ),
          );
        },
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.support_agent_rounded, size: 36),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Widget trendWidget;
  final bool isLoading;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.trendWidget,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 8),
                  const AppShimmer.rectangular(width: 55, height: 32),
                  const SizedBox(height: 8),
                  const AppShimmer.rectangular(width: 100, height: 12),
                ] else ...[
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Metropolis',
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  trendWidget,
                ],
              ],
            ),
          ),
          if (isLoading)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
        ],
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

class _ComplaintQueueItem extends StatefulWidget {
  final ComplaintModel complaint;
  const _ComplaintQueueItem({required this.complaint});

  @override
  State<_ComplaintQueueItem> createState() => _ComplaintQueueItemState();
}

class _ComplaintQueueItemState extends State<_ComplaintQueueItem> {
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
        onTap: () => context.go('/complaints/${complaint.id}'),
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
                          'Street Light Fault - Ward ${complaint.pole?.poleNumber ?? '#${complaint.pole?.id ?? 'N/A'}'}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$timeStr • ID: #${complaint.id}',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                      'குடிநீர் விநியோகம் சீராக இல்லை. சரிசெய்யவும்.';
                  final translationText = complaint.voiceCall?.transcriptEnglish ??
                      complaint.description ??
                      'The street light is not working. Please fix it.';

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
        isSuperAdmin: false,
      );

      if (id != null && context.mounted) {
        await PanchayatAdminRepository().assignElectrician(complaint.id, id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Electrician assigned successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.read<PADashBloc>().add(LoadPADashboard());
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