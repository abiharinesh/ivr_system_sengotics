import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';

class AssistantEngineerDashboardScreen extends StatelessWidget {
  const AssistantEngineerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(), const SizedBox(height: 24), _buildKpiRow(), const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _buildFieldDispatches()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildQuickActions(context)),
      ]),
      const SizedBox(height: 24), _buildRecentInspections(),
    ]));
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0E7490), Color(0xFF06B6D4)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF0E7490).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.precision_manufacturing_rounded, color: Colors.white, size: 32)),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Assistant Engineer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Sub-Division Verification • Contractor Inspections • Field Dispatches',
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
          _kpiCard('Open Complaints', '23', Icons.report_problem_rounded, const Color(0xFFEF4444), 'In my zone'),
          _kpiCard('Pending Inspections', '7', Icons.checklist_rtl_rounded, const Color(0xFFF59E0B), '3 overdue'),
          _kpiCard('Dispatched Repairs', '12', Icons.build_rounded, const Color(0xFF3B82F6), '5 in progress'),
          _kpiCard('Contractor Tasks', '4', Icons.groups_rounded, const Color(0xFF10B981), '1 awaiting QC'),
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

  Widget _buildFieldDispatches() {
    final dispatches = [
      {'id': 'FD-087', 'task': 'Pole TY-006 street light flickering', 'tech': 'Kannan (Electrician)', 'status': 'En Route', 'sColor': const Color(0xFFF59E0B)},
      {'id': 'FD-086', 'task': 'Water leak near Ration Shop Colony', 'tech': 'Senthil (Plumber)', 'status': 'On Site', 'sColor': const Color(0xFF3B82F6)},
      {'id': 'FD-085', 'task': 'Drainage block Ward 2 - Pillaiyar Kovil', 'tech': 'Rajan (JE)', 'status': 'Completed', 'sColor': const Color(0xFF10B981)},
      {'id': 'FD-084', 'task': 'Bus shelter roof panel repair', 'tech': 'Murugan Electricals', 'status': 'Awaiting QC', 'sColor': const Color(0xFF8B5CF6)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.local_shipping_rounded, color: Color(0xFF06B6D4), size: 22),
          const SizedBox(width: 10),
          Text('Active Field Dispatches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...dispatches.map((d) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d['id']}  •  ${d['task']}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text('Assigned: ${d['tech']}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (d['sColor'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(d['status'] as String, style: TextStyle(fontSize: 11, color: d['sColor'] as Color, fontWeight: FontWeight.w600))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.report_problem_rounded, 'label': 'Complaints', 'route': '/complaints', 'color': const Color(0xFFEF4444)},
      {'icon': Icons.checklist_rtl_rounded, 'label': 'Inspections', 'route': '/inspections', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.water_drop_rounded, 'label': 'Water Supply', 'route': '/water/pipeline-grid', 'color': const Color(0xFF06B6D4)},
      {'icon': Icons.alt_route_rounded, 'label': 'Pole Management', 'route': '/poles', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.engineering_outlined, 'label': 'Contractors', 'route': '/contractors', 'color': const Color(0xFF8B5CF6)},
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

  Widget _buildRecentInspections() {
    final inspections = [
      {'item': 'Contractor QC: Drainage work Ward 2', 'result': 'Passed', 'time': '2 hours ago', 'color': const Color(0xFF10B981)},
      {'item': 'Water pipeline joint verification', 'result': 'Rework Needed', 'time': '1 day ago', 'color': const Color(0xFFEF4444)},
      {'item': 'Street light installation TY-003', 'result': 'Passed', 'time': '2 days ago', 'color': const Color(0xFF10B981)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Inspections & Verifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...inspections.map((i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (i['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.checklist_rtl_rounded, color: i['color'] as Color, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(i['item'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            Text(i['time'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: (i['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(i['result'] as String, style: TextStyle(fontSize: 11, color: i['color'] as Color, fontWeight: FontWeight.w600))),
        ]))),
      ]),
    );
  }
}
