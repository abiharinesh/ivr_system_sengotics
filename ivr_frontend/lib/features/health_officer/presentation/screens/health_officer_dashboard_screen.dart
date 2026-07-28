import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';

class HealthOfficerDashboardScreen extends StatelessWidget {
  const HealthOfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(), const SizedBox(height: 24), _buildKpiRow(), const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _buildHealthGrievances()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildQuickActions(context)),
      ]),
      const SizedBox(height: 24), _buildRecentActivity(),
    ]));
  }

  Widget _buildHeader() {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: const Color(0xFF047857).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 32)),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Health Officer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Public Sanitation • Solid Waste Management • Health Grievances',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.75))),
        ])),
      ]),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 900 ? 4 : 2;
      return GridView.count(crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.2, children: [
          _kpiCard('Waste Complaints', '18', Icons.delete_rounded, const Color(0xFFF59E0B), '6 open'),
          _kpiCard('Health Grievances', '7', Icons.medical_services_rounded, const Color(0xFFEF4444), '3 verified'),
          _kpiCard('SWM Coverage', '82%', Icons.recycling_rounded, const Color(0xFF10B981), '↑ 4% this month'),
          _kpiCard('Inspections Done', '24', Icons.checklist_rtl_rounded, const Color(0xFF3B82F6), 'This month'),
        ]);
    });
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, String sub) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 24)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  Widget _buildHealthGrievances() {
    final grievances = [
      {'id': 'HG-012', 'issue': 'Open drain near school — mosquito breeding', 'ward': 'Ward 1 North', 'status': 'Needs Verification', 'sColor': const Color(0xFFEF4444)},
      {'id': 'HG-011', 'issue': 'Garbage not collected for 3 days — Main Rd', 'ward': 'Ward 2 South', 'status': 'Assigned to SWM', 'sColor': const Color(0xFFF59E0B)},
      {'id': 'HG-010', 'issue': 'Stagnant water near Mariamman Temple', 'ward': 'Main Temple Zone', 'status': 'Verified — Spraying done', 'sColor': const Color(0xFF10B981)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.medical_services_rounded, color: const Color(0xFFEF4444), size: 22),
          const SizedBox(width: 10),
          Text('Health Grievance Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...grievances.map((g) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: g['sColor'] as Color, width: 3))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${g['id']}  •  ${g['issue']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(g['ward'] as String, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (g['sColor'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(g['status'] as String, style: TextStyle(fontSize: 11, color: g['sColor'] as Color, fontWeight: FontWeight.w600))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.delete_rounded, 'label': 'Solid Waste Mgmt', 'route': '/municipality/solid-waste', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.medical_services_rounded, 'label': 'Public Health', 'route': '/municipality/health', 'color': const Color(0xFFEF4444)},
      {'icon': Icons.checklist_rtl_rounded, 'label': 'Inspections', 'route': '/inspections', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.report_problem_rounded, 'label': 'Health Complaints', 'route': '/complaints', 'color': const Color(0xFF10B981)},
      {'icon': Icons.account_balance_outlined, 'label': 'Municipality', 'route': '/municipality', 'color': const Color(0xFF64748B)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...actions.map((a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Material(color: Colors.transparent, child: InkWell(
          onTap: () => context.go(a['route'] as String), borderRadius: BorderRadius.circular(10),
          child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20), const SizedBox(width: 12),
              Text(a['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              const Spacer(), Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted)])),
        )))),
      ]),
    );
  }

  Widget _buildRecentActivity() {
    final logs = [
      {'action': 'SWM vehicle route verified — Ward 1 North', 'time': '1 hour ago', 'color': const Color(0xFF10B981)},
      {'action': 'Fogging completed near pond area', 'time': '3 hours ago', 'color': const Color(0xFF3B82F6)},
      {'action': 'Drain cleaning inspection — Main Road', 'time': '1 day ago', 'color': const Color(0xFFF59E0B)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Health Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...logs.map((l) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (l['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.health_and_safety_rounded, color: l['color'] as Color, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l['action'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            Text(l['time'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ])),
        ]))),
      ]),
    );
  }
}
