import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';

class CommissionerDashboardScreen extends StatefulWidget {
  const CommissionerDashboardScreen({super.key});

  @override
  State<CommissionerDashboardScreen> createState() =>
      _CommissionerDashboardScreenState();
}

class _CommissionerDashboardScreenState
    extends State<CommissionerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),
          _buildKpiRow(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildSlaBreach()),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildQuickActions()),
            ],
          ),
          const SizedBox(height: 24),
          _buildRecentApprovals(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    final softwareName = user?.dynamicSoftwareName ?? 'நகராட்சி குரல்';
    final branchName = user?.panchayatName ?? '';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF2D5F8B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.account_balance_rounded,
                color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$softwareName — Executive Control',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${branchName.isNotEmpty ? "$branchName • " : ""}Municipal Commissioner Command Center',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          _buildDateBadge(),
        ],
      ),
    );
  }

  Widget _buildDateBadge() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '${now.day}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            '${months[now.month - 1]} ${now.year}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _kpiCard('SLA Compliance', '94.2%', Icons.verified_rounded,
                const Color(0xFF10B981), '+2.1% this week'),
            _kpiCard('Total Complaints', '1,247', Icons.report_problem_rounded,
                const Color(0xFFF59E0B), '38 today'),
            _kpiCard('Resolution Rate', '87.6%', Icons.check_circle_rounded,
                const Color(0xFF3B82F6), '↑ 3.4%'),
            _kpiCard('Pending Approvals', '12', Icons.pending_actions_rounded,
                const Color(0xFFEF4444), '3 urgent'),
          ],
        );
      },
    );
  }

  Widget _kpiCard(
      String title, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11, color: color, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlaBreach() {
    final breaches = [
      {'id': 'CMP-2026-001247', 'type': 'Street Light', 'ward': 'Ward 1 North', 'hours': '72h overdue', 'severity': 'critical'},
      {'id': 'CMP-2026-001198', 'type': 'Water Leak', 'ward': 'Ward 2 South', 'hours': '48h overdue', 'severity': 'high'},
      {'id': 'CMP-2026-001156', 'type': 'Road Damage', 'ward': 'Main Temple Zone', 'hours': '24h overdue', 'severity': 'medium'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 10),
              Text('SLA Breach Alerts',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${breaches.length} Active',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...breaches.map((b) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    left: BorderSide(
                      color: b['severity'] == 'critical'
                          ? const Color(0xFFEF4444)
                          : b['severity'] == 'high'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF3B82F6),
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['id']!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text('${b['type']} • ${b['ward']}',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(b['hours']!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.gavel_rounded, 'label': 'Approve Tenders', 'route': '/tenders', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.task_alt_rounded, 'label': 'Review Certificates', 'route': '/revenue/certificates', 'color': const Color(0xFF10B981)},
      {'icon': Icons.analytics_rounded, 'label': 'SLA Analytics', 'route': '/analytics/sla', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.report_problem_rounded, 'label': 'All Complaints', 'route': '/complaints', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.dashboard_rounded, 'label': 'Executive Dashboard', 'route': '/dashboard/executive', 'color': const Color(0xFF1E3A5F)},
      {'icon': Icons.approval_rounded, 'label': 'Approvals Inbox', 'route': '/approvals', 'color': const Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          ...actions.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.go(a['route'] as String),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(a['icon'] as IconData,
                              color: a['color'] as Color, size: 20),
                          const SizedBox(width: 12),
                          Text(a['label'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary)),
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildRecentApprovals() {
    final approvals = [
      {'action': 'Tender #TND-042 awarded to Murugan Electricals', 'time': '2 hours ago', 'icon': Icons.gavel_rounded, 'color': const Color(0xFF8B5CF6)},
      {'action': 'Birth Certificate BC-2026-0891 approved & signed', 'time': '5 hours ago', 'icon': Icons.description_rounded, 'color': const Color(0xFF10B981)},
      {'action': 'SLA breach escalation for CMP-2026-001198 resolved', 'time': '1 day ago', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFF59E0B)},
      {'action': 'Infrastructure approval: Water pipeline extension Ward 3', 'time': '2 days ago', 'icon': Icons.water_drop_rounded, 'color': const Color(0xFF3B82F6)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Administrative Approvals',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          ...approvals.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (a['color'] as Color).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(a['icon'] as IconData,
                          color: a['color'] as Color, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['action'] as String,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500)),
                          Text(a['time'] as String,
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
