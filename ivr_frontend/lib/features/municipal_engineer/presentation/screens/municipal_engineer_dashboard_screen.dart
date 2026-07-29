import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';

class MunicipalEngineerDashboardScreen extends StatefulWidget {
  const MunicipalEngineerDashboardScreen({super.key});

  @override
  State<MunicipalEngineerDashboardScreen> createState() =>
      _MunicipalEngineerDashboardScreenState();
}

class _MunicipalEngineerDashboardScreenState
    extends State<MunicipalEngineerDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildKpiRow(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildActiveProjects()),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _buildQuickActions()),
            ],
          ),
          const SizedBox(height: 24),
          _buildRecentWorkOrders(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0D47A1).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.engineering_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Municipal Engineer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Technical Infrastructure • Capital Projects • Engineering Workflows',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75))),
              ],
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
          crossAxisCount: crossCount, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.2,
          children: [
            _kpiCard('Active Projects', '8', Icons.construction_rounded, const Color(0xFF3B82F6), '2 capital works'),
            _kpiCard('Infra Health', '91%', Icons.health_and_safety_rounded, const Color(0xFF10B981), '↑ 1.8%'),
            _kpiCard('Pending Inspections', '14', Icons.checklist_rtl_rounded, const Color(0xFFF59E0B), '5 this week'),
            _kpiCard('Contractors Active', '6', Icons.groups_rounded, const Color(0xFF8B5CF6), '2 new bids'),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            Text(sub, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
          ],
        )),
      ]),
    );
  }

  Widget _buildActiveProjects() {
    final projects = [
      {'name': 'Ward 3 Street Light Upgrade', 'progress': 0.75, 'status': 'In Progress', 'cost': '₹4.2L', 'contractor': 'Murugan Electricals'},
      {'name': 'Underground Drainage Phase-II', 'progress': 0.45, 'status': 'In Progress', 'cost': '₹18.5L', 'contractor': 'TN Civil Corp'},
      {'name': 'Bus Shelter Construction - Main Rd', 'progress': 0.90, 'status': 'Nearing Completion', 'cost': '₹2.8L', 'contractor': 'Local Builders'},
      {'name': 'Water Pipeline Extension Ward 5', 'progress': 0.20, 'status': 'Just Started', 'cost': '₹8.1L', 'contractor': 'Aqua Works'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.construction_rounded, color: Color(0xFF3B82F6), size: 22),
            const SizedBox(width: 10),
            Text('Capital Projects', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          ]),
          const SizedBox(height: 16),
          ...projects.map((p) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(p['name'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                Text(p['cost'] as String, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Text('${p['contractor']}', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const Spacer(),
                Text(p['status'] as String, style: const TextStyle(fontSize: 11, color: Color(0xFF3B82F6), fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: p['progress'] as double,
                  backgroundColor: AppTheme.stroke,
                  valueColor: AlwaysStoppedAnimation(
                    (p['progress'] as double) > 0.8 ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
                  ),
                  minHeight: 6,
                ),
              ),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.alt_route_rounded, 'label': 'Pole Management', 'route': '/poles', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.water_drop_rounded, 'label': 'Water Supply', 'route': '/water/pipeline-grid', 'color': const Color(0xFF06B6D4)},
      {'icon': Icons.engineering_outlined, 'label': 'Contractors', 'route': '/contractors', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.assignment_rounded, 'label': 'Tenders', 'route': '/tenders', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.checklist_rtl_rounded, 'label': 'Field Inspections', 'route': '/inspections', 'color': const Color(0xFF10B981)},
      {'icon': Icons.report_problem_rounded, 'label': 'Complaints', 'route': '/complaints', 'color': const Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(color: Colors.transparent, child: InkWell(
            onTap: () => context.go(a['route'] as String),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
                const SizedBox(width: 12),
                Text(a['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
              ]),
            ),
          )),
        )),
      ]),
    );
  }

  Widget _buildRecentWorkOrders() {
    final orders = [
      {'wo': 'WO-2026-000042', 'title': 'Street light replacement TY-006', 'status': 'In Progress', 'color': const Color(0xFF3B82F6)},
      {'wo': 'WO-2026-000041', 'title': 'Drainage repair near bus stand', 'status': 'Verified', 'color': const Color(0xFF10B981)},
      {'wo': 'WO-2026-000040', 'title': 'Water main valve replacement', 'status': 'Pending QC', 'color': const Color(0xFFF59E0B)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Work Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...orders.map((o) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: (o['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.assignment_rounded, color: o['color'] as Color, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o['wo'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              Text(o['title'] as String, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: (o['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(o['status'] as String, style: TextStyle(fontSize: 11, color: o['color'] as Color, fontWeight: FontWeight.w600)),
            ),
          ]),
        )),
      ]),
    );
  }
}
