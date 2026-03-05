import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../config/app_theme.dart';
import '../../../core/widgets/stat_card.dart';
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
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 12),
                Text(state.message, style: const TextStyle(color: AppTheme.textSecondary)),
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

    return RefreshIndicator(
      onRefresh: () async {
        context.read<PADashBloc>().add(LoadPADashboard());
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      profile.email.isNotEmpty
                          ? profile.email[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.panchayatName ?? 'Your Panchayat',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.email,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
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
                      title: 'Electric Poles',
                      value: (stats.totalPoles ?? 0).toString(),
                      icon: Icons.electrical_services_rounded,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
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
