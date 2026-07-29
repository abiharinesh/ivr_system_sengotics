import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';

class JuniorEngineerDashboardScreen extends StatelessWidget {
  const JuniorEngineerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(), const SizedBox(height: 24), _buildKpiRow(), const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _buildAssignedTasks()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildQuickActions(context)),
      ]),
      const SizedBox(height: 24), _buildVerificationLog(),
    ]));
  }

  Widget _buildHeader() {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF60A5FA)]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: const Color(0xFF1D4ED8).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.architecture_rounded, color: Colors.white, size: 32)),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Junior Engineer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Ground Inspections • Work Order Verification • Quality Checks',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75))),
        ])),
      ]),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 900 ? 4 : 2;
      return GridView.count(crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.2, children: [
          _kpiCard('Assigned', '6', Icons.assignment_rounded, const Color(0xFF3B82F6), 'Inspections'),
          _kpiCard('Completed', '18', Icons.check_circle_rounded, const Color(0xFF10B981), 'This month'),
          _kpiCard('QC Done', '12', Icons.verified_rounded, const Color(0xFF8B5CF6), 'Quality checks'),
          _kpiCard('Pending', '3', Icons.pending_actions_rounded, const Color(0xFFF59E0B), 'Awaiting action'),
        ]);
    });
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, String sub) {
    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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

  Widget _buildAssignedTasks() {
    final tasks = [
      {'title': 'Inspect street light installation TY-009', 'type': 'Electrical', 'priority': 'High', 'pColor': const Color(0xFFEF4444)},
      {'title': 'Verify drainage work completion - Ward 2', 'type': 'Civil', 'priority': 'Medium', 'pColor': const Color(0xFFF59E0B)},
      {'title': 'Water pipeline joint QC - Annur Trunk', 'type': 'Water', 'priority': 'High', 'pColor': const Color(0xFFEF4444)},
      {'title': 'Road patch quality check - Bus Stand Rd', 'type': 'Civil', 'priority': 'Low', 'pColor': const Color(0xFF10B981)},
      {'title': 'Pole foundation measurement - TH-003', 'type': 'Electrical', 'priority': 'Medium', 'pColor': const Color(0xFFF59E0B)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF3B82F6), size: 22),
          const SizedBox(width: 10),
          Text('My Assigned Tasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${tasks.length} tasks', style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 16),
        ...tasks.map((t) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
              color: (t['pColor'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.flag_rounded, color: t['pColor'] as Color, size: 16)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t['title'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              Text(t['type'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: (t['pColor'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(t['priority'] as String, style: TextStyle(fontSize: 10, color: t['pColor'] as Color, fontWeight: FontWeight.w600))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.checklist_rtl_rounded, 'label': 'Field Inspections', 'route': '/inspections', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.alt_route_rounded, 'label': 'Pole Management', 'route': '/poles', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.water_drop_rounded, 'label': 'Water Supply', 'route': '/water/pipeline-grid', 'color': const Color(0xFF06B6D4)},
      {'icon': Icons.report_problem_rounded, 'label': 'Complaints', 'route': '/complaints', 'color': const Color(0xFFEF4444)},
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

  Widget _buildVerificationLog() {
    final verifications = [
      {'item': 'WO-2026-000042 — Street light fix verified ✓', 'time': '2 hours ago', 'color': const Color(0xFF10B981)},
      {'item': 'WO-2026-000041 — Drainage clearance rework needed', 'time': '1 day ago', 'color': const Color(0xFFEF4444)},
      {'item': 'Pole TY-005 foundation measurement logged', 'time': '2 days ago', 'color': const Color(0xFF3B82F6)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Verifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...verifications.map((v) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (v['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.verified_rounded, color: v['color'] as Color, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v['item'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            Text(v['time'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ])),
        ]))),
      ]),
    );
  }
}
