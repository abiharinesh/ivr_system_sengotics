import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_theme.dart';

class ContractorDashboardScreen extends StatelessWidget {
  const ContractorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(), const SizedBox(height: 24), _buildKpiRow(), const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _buildActiveTenders()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildQuickActions(context)),
      ]),
      const SizedBox(height: 24), _buildContractActivity(),
    ]));
  }

  Widget _buildHeader() {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF92400E), Color(0xFFF59E0B)]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: const Color(0xFF92400E).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.business_center_rounded, color: Colors.white, size: 32)),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Contractor Portal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Digital Tender Bidding • Work Order Tracking • Contract Management',
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
          _kpiCard('Active Tenders', '3', Icons.gavel_rounded, const Color(0xFFF59E0B), 'Open for bidding'),
          _kpiCard('Bids Submitted', '5', Icons.send_rounded, const Color(0xFF3B82F6), '2 under review'),
          _kpiCard('Contracts Won', '2', Icons.emoji_events_rounded, const Color(0xFF10B981), 'This FY'),
          _kpiCard('Work Orders', '4', Icons.assignment_rounded, const Color(0xFF8B5CF6), '1 in progress'),
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

  Widget _buildActiveTenders() {
    final tenders = [
      {'id': 'TND-045', 'title': 'LED Street Light Installation — Ward 3', 'budget': '₹6.5L', 'deadline': '15 Aug 2026', 'status': 'Open', 'sColor': const Color(0xFF10B981)},
      {'id': 'TND-044', 'title': 'Underground Drainage Phase-III', 'budget': '₹24.0L', 'deadline': '20 Aug 2026', 'status': 'Open', 'sColor': const Color(0xFF10B981)},
      {'id': 'TND-043', 'title': 'Community Hall Renovation', 'budget': '₹8.2L', 'deadline': '10 Aug 2026', 'status': 'Bid Submitted', 'sColor': const Color(0xFF3B82F6)},
      {'id': 'TND-042', 'title': 'Water Pipeline Extension Ward 5', 'budget': '₹12.0L', 'deadline': 'Closed', 'status': 'Awarded ✓', 'sColor': const Color(0xFF8B5CF6)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B), size: 22),
          const SizedBox(width: 10),
          Text('Tender Opportunities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...tenders.map((t) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(t['id'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              Text(t['budget'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
            ]),
            const SizedBox(height: 4),
            Text(t['title'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(t['deadline'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
      {'icon': Icons.gavel_rounded, 'label': 'Tender Bidding Portal', 'route': '/tenders/vendor-portal', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.assignment_rounded, 'label': 'My Work Orders', 'route': '/work-orders/new', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.folder_rounded, 'label': 'My Documents', 'route': '/documents', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.assignment_rounded, 'label': 'All Tenders', 'route': '/tenders', 'color': const Color(0xFF10B981)},
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

  Widget _buildContractActivity() {
    final activity = [
      {'action': 'Work order WO-2026-000042 received — Street light installation', 'time': '1 day ago', 'color': const Color(0xFF3B82F6)},
      {'action': 'Tender TND-043 bid submitted — ₹7.8L quoted', 'time': '3 days ago', 'color': const Color(0xFFF59E0B)},
      {'action': 'MBook entry verified for WO-2026-000040', 'time': '1 week ago', 'color': const Color(0xFF10B981)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Contract Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...activity.map((a) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (a['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.business_center_rounded, color: a['color'] as Color, size: 18)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['action'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
            Text(a['time'] as String, style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ])),
        ]))),
      ]),
    );
  }
}
