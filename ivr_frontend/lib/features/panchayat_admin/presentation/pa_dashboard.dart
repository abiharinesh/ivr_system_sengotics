import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/dashboard_category_breakdown_card.dart';
import '../../../core/widgets/dashboard_recent_activity_card.dart';
import '../../../core/widgets/dashboard_resolution_trend_card.dart';
import '../../../core/widgets/map_overview.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../models/pole_model.dart';
import '../bloc/pa_dashboard_bloc.dart';

class PADashboard extends StatelessWidget {
  const PADashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PADashBloc, PADashState>(
      builder: (context, state) {
        if (state is PADashLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is PADashError) {
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
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      () => context.read<PADashBloc>().add(LoadPADashboard()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is PADashLoaded) {
          return _buildContent(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildContent(BuildContext context, PADashLoaded state) {
    final stats = state.stats;
    final profile = state.profile;
    final titlePanchayat = profile.panchayatName ?? 'This Panchayat';
    final padding = MediaQuery.sizeOf(context).width < 600 ? 12.0 : 24.0;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<PADashBloc>().add(LoadPADashboard());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.warningMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Some dashboard data is temporarily unavailable. Pull to refresh.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.read<PADashBloc>().add(LoadPADashboard()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final crossAxisCount = w > 900 ? 4 : 2;
                final isMobile = w < 600;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isMobile ? 1.45 : 1.85,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      title: 'Total Complaints',
                      value: stats.totalComplaints.toString(),
                      icon: Icons.report_problem_rounded,
                      gradient: AppTheme.primaryGradient,
                      delta: '+12%',
                    ),
                    StatCard(
                      title: 'Pending',
                      value: stats.pendingComplaints.toString(),
                      icon: Icons.schedule_rounded,
                      gradient: AppTheme.warningGradient,
                      delta: '-3%',
                      positiveDelta: false,
                    ),
                    StatCard(
                      title: 'Resolved',
                      value: stats.resolvedComplaints.toString(),
                      icon: Icons.check_circle_rounded,
                      gradient: AppTheme.accentGradient,
                      delta: '+8%',
                    ),
                    StatCard(
                      title: 'Active Pole Issues',
                      value:
                          (((stats.totalPoles ?? 0) * 0.2).round()).toString(),
                      icon: Icons.warning_amber_rounded,
                      gradient: AppTheme.errorGradient,
                      delta: '+5%',
                      positiveDelta: false,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            _MapDesignCard(
              totalPoles: state.poles.length,
              panchayatName: titlePanchayat,
              poles: state.poles,
            ),
            const SizedBox(height: 20),

            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumn = constraints.maxWidth > 980;
                final trend = DashboardResolutionTrendCard(
                  trend: state.insights.resolutionTrend,
                );
                final category = DashboardCategoryBreakdownCard(
                  categories: state.insights.byCategory,
                );
                if (!twoColumn) {
                  return Column(
                    children: [
                      trend,
                      const SizedBox(height: 16),
                      category,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: trend),
                    const SizedBox(width: 16),
                    Expanded(child: category),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            DashboardRecentActivityCard(
              items: state.insights.recentActivity,
              onViewAll: () => context.go('/complaints'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDesignCard extends StatefulWidget {
  final int totalPoles;
  final String panchayatName;
  final List<PoleModel> poles;
  const _MapDesignCard({
    required this.totalPoles,
    required this.panchayatName,
    required this.poles,
  });

  @override
  State<_MapDesignCard> createState() => _MapDesignCardState();
}

class _MapDesignCardState extends State<_MapDesignCard> {
  PoleModel? _selectedPole;

  bool _isFault(PoleModel pole) => pole.hasCriticalIssues;

  String _statusLabel(PoleModel pole) {
    if (_isFault(pole)) return 'ALERT: FAULTY';
    if (pole.hasManualReviewIssues) return 'ALERT: MANUAL REVIEW';
    if (pole.keypadId == null) return 'STATUS: INACTIVE';
    return 'STATUS: ACTIVE';
  }

  Color _statusColor(PoleModel pole) {
    if (_isFault(pole)) return AppTheme.error;
    if (pole.hasManualReviewIssues) return AppTheme.warning;
    if (pole.keypadId == null) return AppTheme.textMuted;
    return AppTheme.accent;
  }

  String _poleDisplayId(PoleModel pole) {
    final number = pole.poleNumber?.trim();
    if (number == null || number.isEmpty) return 'PL-${pole.id}';
    return number;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final compact = w < 760;
        final veryCompact = w < 540;
        final ultraCompact = w < 380;
        final mapHeight = veryCompact ? 280.0 : 300.0;
        final infoCardWidth =
            (w - 44).clamp(140.0, 230.0).toDouble();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke),
            boxShadow: AppTheme.softShadow,
          ),
          child: Padding(
            padding: EdgeInsets.all(veryCompact ? 10 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compact) ...[
                  Text(
                    ultraCompact ? 'Asset Map (GIS)' : 'Panchayat Asset Map (GIS View)',
                    style: TextStyle(
                      fontSize: ultraCompact ? 16 : 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time status in ${widget.panchayatName}',
                    style: TextStyle(
                      fontSize: ultraCompact ? 12 : 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _tab('All Wards', true),
                      _tab('Poles', false),
                      _tab('Complaints', false),
                      _tab('Faults', false),
                    ],
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Panchayat Asset Map (GIS View)',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Real-time status in ${widget.panchayatName}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _tab('All Wards', true),
                      const SizedBox(width: 6),
                      _tab('Poles', false),
                      const SizedBox(width: 6),
                      _tab('Complaints', false),
                      const SizedBox(width: 6),
                      _tab('Faults', false),
                    ],
                  ),
                SizedBox(height: veryCompact ? 10 : 14),
                Container(
                  height: mapHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned.fill(
                        child: MapOverview(
                          poles: widget.poles,
                          height: mapHeight,
                          showLegend: false,
                          showCardDecoration: false,
                          borderRadius: 12,
                          showInfoWindow: false,
                          focusFaultPolesFirst: true,
                          usePngMarkers: true,
                          onPoleTap:
                              (pole) => setState(() => _selectedPole = pole),
                        ),
                      ),
                      Positioned(
                        left: veryCompact ? 6 : 16,
                        bottom: veryCompact ? 6 : 16,
                        child: Container(
                          width: ultraCompact ? 95 : (veryCompact ? 110 : 130),
                          padding: EdgeInsets.all(veryCompact ? 6 : 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'LEGEND',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 6),
                              _LegendRow('Active (Healthy)', Color(0xFF10B981)),
                              SizedBox(height: 4),
                              _LegendRow('Maintenance Due', Color(0xFFF59E0B)),
                              SizedBox(height: 4),
                              _LegendRow('Critical Fault', Color(0xFFEF4444)),
                            ],
                          ),
                        ),
                      ),
                      if (_selectedPole != null)
                        Align(
                          alignment:
                              veryCompact
                                  ? Alignment.bottomCenter
                                  : Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: veryCompact ? 0 : 16,
                              top: veryCompact ? 0 : 42,
                              bottom: veryCompact ? 56 : 0,
                            ),
                            child: Container(
                              width: ultraCompact ? w - 24 : infoCardWidth,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: AppTheme.softShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _statusLabel(_selectedPole!),
                                        style: TextStyle(
                                          color: _statusColor(_selectedPole!),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const Spacer(),
                                      InkWell(
                                        onTap:
                                            () =>
                                                setState(() => _selectedPole = null),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: AppTheme.textMuted.withValues(
                                            alpha: 0.7,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Pole ID: ${_poleDisplayId(_selectedPole!)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Panchayat: ${widget.panchayatName}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pending: ${_selectedPole!.pendingComplaints}, '
                                    'Processing: ${_selectedPole!.inProgressComplaints}, '
                                    'Manual: ${_selectedPole!.manualReviewComplaints}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Keypad: ${_selectedPole!.keypadId ?? 'Not linked'}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: () {},
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: const Text(
                                        'Assign Task',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: veryCompact ? 6 : null,
                        right: veryCompact ? 6 : 16,
                        bottom: veryCompact ? 6 : 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${widget.totalPoles} assets tracked',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF3F4F6) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: active ? AppTheme.textPrimary : AppTheme.textSecondary,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendRow(this.label, this.color);

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
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
