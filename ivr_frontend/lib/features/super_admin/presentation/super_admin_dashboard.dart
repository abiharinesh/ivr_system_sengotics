import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/stat_card.dart';
import '../bloc/dashboard_bloc.dart';

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SADashBloc, SADashState>(
      builder: (context, state) {
        if (state is SADashLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is SADashError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text(state.message, style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.read<SADashBloc>().add(LoadSADashboard()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state is SADashLoaded) {
          return _buildDashboard(context, state);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildDashboard(BuildContext context, SADashLoaded state) {
    final stats = state.stats;
    return RefreshIndicator(
      onRefresh: () async {
        context.read<SADashBloc>().add(LoadSADashboard());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Monitor and manage your entire IVR system',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 4
                    : constraints.maxWidth > 600
                        ? 2
                        : 1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.6,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      title: 'Total Complaints',
                      value: stats.totalComplaints.toString(),
                      icon: Icons.report_problem_rounded,
                      gradient: AppTheme.primaryGradient,
                    ),
                    StatCard(
                      title: 'Pending',
                      value: stats.pendingComplaints.toString(),
                      icon: Icons.pending_actions_rounded,
                      gradient: AppTheme.warningGradient,
                    ),
                    StatCard(
                      title: 'Resolved',
                      value: stats.resolvedComplaints.toString(),
                      icon: Icons.check_circle_rounded,
                      gradient: AppTheme.accentGradient,
                    ),
                    StatCard(
                      title: 'Manual Review',
                      value: stats.manualReviewComplaints.toString(),
                      icon: Icons.rate_review_rounded,
                      gradient: AppTheme.errorGradient,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Secondary Stats
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900
                    ? 3
                    : constraints.maxWidth > 600
                        ? 3
                        : 1;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      title: 'Total Panchayats',
                      value: (stats.totalPanchayats ?? 0).toString(),
                      icon: Icons.location_city_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                      ),
                    ),
                    StatCard(
                      title: 'Electric Poles',
                      value: (stats.totalPoles ?? 0).toString(),
                      icon: Icons.electrical_services_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                      ),
                    ),
                    StatCard(
                      title: 'Total Admins',
                      value: (stats.totalAdmins ?? 0).toString(),
                      icon: Icons.admin_panel_settings_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
