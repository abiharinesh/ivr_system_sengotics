import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/dashboard_panels.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _kpi('Average Resolution Time', '18.4 hrs', '+6% vs last week'),
              _kpi('First Response Rate', '92%', '+3% vs last week'),
              _kpi('IVR Containment', '71%', 'Handled without agent'),
              _kpi('Citizen Satisfaction', '4.3 / 5', 'From post-call surveys'),
            ],
          ),
          const SizedBox(height: 20),
          const _AnalyticsPanels(),
        ],
      ),
    );
  }

  Widget _kpi(String title, String value, String subtitle) {
    return SizedBox(
      width: 260,
      child: DashboardPanel(
        title: title,
        subtitle: subtitle,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Text(
          value,
          style:       TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AnalyticsPanels extends StatelessWidget {
  const _AnalyticsPanels();

  @override
  Widget build(BuildContext context) {
    final trendValues = [12.0, 18.0, 22.0, 26.0, 23.0, 30.0, 28.0];
    final categoryItems = [
      const CategoryProgressItem(
        label: 'Street Lighting',
        progress: 0.78,
        color: Color(0xFF3B82F6),
      ),
      const CategoryProgressItem(
        label: 'Water Supply',
        progress: 0.64,
        color: Color(0xFF10B981),
      ),
      const CategoryProgressItem(
        label: 'Road Maintenance',
        progress: 0.52,
        color: Color(0xFFF59E0B),
      ),
      const CategoryProgressItem(
        label: 'Waste Management',
        progress: 0.88,
        color: Color(0xFF8B5CF6),
      ),
    ];

    final activity = [
            ActivityFeedItem(
        icon: Icons.campaign_rounded,
        color: AppTheme.primary,
        title: 'IVR campaign sent',
        subtitle: 'Power cut alert broadcast to Ward 3 and 4',
        timeLabel: '18 mins ago',
      ),
            ActivityFeedItem(
        icon: Icons.check_circle_rounded,
        color: AppTheme.accent,
        title: 'Bulk complaints resolved',
        subtitle: '12 lighting complaints closed in Ward 1',
        timeLabel: '1 hr ago',
      ),
      const ActivityFeedItem(
        icon: Icons.trending_up_rounded,
        color: AppTheme.warning,
        title: 'Spike in calls',
        subtitle: 'Unusual IVR traffic from Ward 6 detected',
        timeLabel: '3 hrs ago',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 980;
        if (!wide) {
          return Column(
            children: [
              DashboardPanel(
                title: 'Weekly Complaint Trend',
                subtitle: 'Total complaints created vs resolved',
                child: MiniTrendChart(values: trendValues),
              ),
              const SizedBox(height: 16),
              DashboardPanel(
                title: 'By Category',
                subtitle: 'Resolution performance by issue type',
                child: CategoryProgressList(items: categoryItems),
              ),
              const SizedBox(height: 16),
              DashboardPanel(
                title: 'Operations Feed',
                subtitle: 'Recent IVR & complaint activity',
                child: ActivityFeed(items: activity),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  DashboardPanel(
                    title: 'Weekly Complaint Trend',
                    subtitle: 'Total complaints created vs resolved',
                    child: MiniTrendChart(values: trendValues),
                  ),
                  const SizedBox(height: 16),
                  DashboardPanel(
                    title: 'Operations Feed',
                    subtitle: 'Recent IVR & complaint activity',
                    child: ActivityFeed(items: activity),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DashboardPanel(
                title: 'By Category',
                subtitle: 'Resolution performance by issue type',
                child: CategoryProgressList(items: categoryItems),
              ),
            ),
          ],
        );
      },
    );
  }
}
