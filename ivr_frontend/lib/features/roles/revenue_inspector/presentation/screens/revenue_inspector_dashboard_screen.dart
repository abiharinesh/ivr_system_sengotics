import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';

class RevenueInspectorDashboardScreen extends StatelessWidget {
  const RevenueInspectorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildHeader(), const SizedBox(height: 24), _buildKpiRow(), const SizedBox(height: 24),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 3, child: _buildDailyInspectionLog()),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: _buildQuickActions(context)),
      ]),
    ]));
  }

  Widget _buildHeader() {
    return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFA855F7)]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: const Color(0xFF9333EA).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 32)),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Revenue Inspector', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Stall Fee Checks • Lease Audits • Revenue Inspection Logging',
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
          _kpiCard('Fees Collected', '₹4,200', Icons.currency_rupee_rounded, const Color(0xFF10B981), 'Today'),
          _kpiCard('Pending Audits', '5', Icons.pending_actions_rounded, const Color(0xFFF59E0B), '2 market stalls'),
          _kpiCard('Inspections Done', '8', Icons.checklist_rtl_rounded, const Color(0xFF3B82F6), 'Today'),
          _kpiCard('Revenue Logged', '₹18,400', Icons.receipt_long_rounded, const Color(0xFF8B5CF6), 'This week'),
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

  Widget _buildDailyInspectionLog() {
    final logs = [
      {'time': '09:15 AM', 'action': 'Market stall #12 — Ravi Fruits — Fee ₹200 collected', 'type': 'Collection', 'color': const Color(0xFF10B981)},
      {'time': '09:45 AM', 'action': 'Market stall #18 — Kumar Flowers — Fee overdue by 2 days', 'type': 'Overdue', 'color': const Color(0xFFEF4444)},
      {'time': '10:30 AM', 'action': 'Ad hoarding audit — Main Rd junction — Lease valid', 'type': 'Audit', 'color': const Color(0xFF3B82F6)},
      {'time': '11:00 AM', 'action': 'Market stall #5 — Lakshmi Vegetables — Fee ₹200 collected', 'type': 'Collection', 'color': const Color(0xFF10B981)},
      {'time': '11:45 AM', 'action': 'Pole lease #PL-008 — Ad banner expired — Notice issued', 'type': 'Notice', 'color': const Color(0xFFF59E0B)},
      {'time': '02:00 PM', 'action': 'Community hall booking payment ₹3,000 verified', 'type': 'Verification', 'color': const Color(0xFF8B5CF6)},
    ];

    return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
      color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.today_rounded, color: Color(0xFF9333EA), size: 22),
          const SizedBox(width: 10),
          Text("Today's Inspection Log", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...logs.map((l) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: l['color'] as Color, width: 3))),
          child: Row(children: [
            SizedBox(width: 70, child: Text(l['time'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted))),
            const SizedBox(width: 10),
            Expanded(child: Text(l['action'] as String, style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: (l['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(l['type'] as String, style: TextStyle(fontSize: 10, color: l['color'] as Color, fontWeight: FontWeight.w600))),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.storefront_rounded, 'label': 'Market Fees', 'route': '/revenue/markets', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.ad_units_rounded, 'label': 'Ad Campaign Audits', 'route': '/revenue/ads', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.domain_rounded, 'label': 'Asset Inspections', 'route': '/revenue/assets', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.receipt_long_rounded, 'label': 'Revenue Reports', 'route': '/report-generation', 'color': const Color(0xFF10B981)},
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
