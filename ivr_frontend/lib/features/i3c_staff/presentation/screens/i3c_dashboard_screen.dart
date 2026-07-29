import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';

class I3cDashboardScreen extends StatelessWidget {
  const I3cDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(), const SizedBox(height: 24), _buildKpiRow(), const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _buildLiveTicketFeed()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildQuickActions(context)),
      ]),
    ]));
  }

  Widget _buildHeader() {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF334155)]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
          borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 32)),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('I3C Command Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('LIVE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ])),
          ]),
          const SizedBox(height: 4),
          Text('Live Ticket Routing • GIS Data Collection • Municipal Officer Support',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.65))),
        ])),
      ]),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 900 ? 4 : 2;
      return GridView.count(crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.2, children: [
          _kpiCard('Live Tickets', '14', Icons.confirmation_number_rounded, const Color(0xFFEF4444), '5 unassigned'),
          _kpiCard('Routed Today', '42', Icons.route_rounded, const Color(0xFF3B82F6), '↑ 8 vs yesterday'),
          _kpiCard('Avg Route Time', '3.2 min', Icons.timer_rounded, const Color(0xFF10B981), '↓ 0.4 min'),
          _kpiCard('GIS Captures', '18', Icons.map_rounded, const Color(0xFF8B5CF6), 'Today'),
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

  Widget _buildLiveTicketFeed() {
    final tickets = [
      {'id': 'TKT-1247', 'caller': '+91 98765 43210', 'issue': 'Street light not working near school', 'ward': 'Ward 1 North', 'ago': '2 min ago', 'status': 'Unassigned', 'sColor': const Color(0xFFEF4444)},
      {'id': 'TKT-1246', 'caller': '+91 98765 43211', 'issue': 'Water pipe burst — Ration Shop Rd', 'ward': 'Ward 2 South', 'ago': '8 min ago', 'status': 'Routed to Plumber', 'sColor': const Color(0xFF3B82F6)},
      {'id': 'TKT-1245', 'caller': 'IVR Auto', 'issue': 'Garbage overflow — Bus Stand', 'ward': 'Main Temple Zone', 'ago': '15 min ago', 'status': 'Routed to SWM', 'sColor': const Color(0xFF10B981)},
      {'id': 'TKT-1244', 'caller': '+91 98765 43001', 'issue': 'Road pothole hazard', 'ward': 'Ward 1 North', 'ago': '22 min ago', 'status': 'Routed to AE', 'sColor': const Color(0xFF10B981)},
      {'id': 'TKT-1243', 'caller': 'QR Scan', 'issue': 'Pole TY-007 leaning dangerously', 'ward': 'Ward 2 South', 'ago': '30 min ago', 'status': 'Unassigned', 'sColor': const Color(0xFFEF4444)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.stream_rounded, color: Color(0xFFEF4444), size: 22),
          const SizedBox(width: 10),
          Text('Live Ticket Feed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${tickets.where((t) => t['status'] == 'Unassigned').length} unassigned',
                style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 16),
        ...tickets.map((t) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: t['sColor'] as Color, width: 3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t['id'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Text('• ${t['caller']}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const Spacer(),
              Text(t['ago'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 4),
            Text(t['issue'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(children: [
              Text(t['ward'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              const Spacer(),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: (t['sColor'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(t['status'] as String, style: TextStyle(fontSize: 10, color: t['sColor'] as Color, fontWeight: FontWeight.w600))),
            ]),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.report_problem_rounded, 'label': 'Route Complaints', 'route': '/complaints', 'color': const Color(0xFFEF4444)},
      {'icon': Icons.map_rounded, 'label': 'GIS Data / Zones', 'route': '/zone-management', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.call_rounded, 'label': 'Voice Calls', 'route': '/voice-calls', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.receipt_long_rounded, 'label': 'IVR Logs', 'route': '/ivr-logs', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.manage_search_rounded, 'label': 'Search', 'route': '/search', 'color': const Color(0xFF10B981)},
      {'icon': Icons.water_drop_rounded, 'label': 'Water Supply', 'route': '/water/pipeline-grid', 'color': const Color(0xFF06B6D4)},
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
}
