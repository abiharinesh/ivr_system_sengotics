import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/config/app_theme.dart';

class RevenueOfficerDashboardScreen extends StatelessWidget {
  const RevenueOfficerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildKpiRow(),
        const SizedBox(height: 24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: _buildRevenueBreakdown()),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: _buildQuickActions(context)),
        ]),
        const SizedBox(height: 24),
        _buildAuditLog(),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF6D28D9).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Revenue Officer', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Revenue Engine • Commercial Leases • Fee Collection • Audit Oversight',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75))),
        ])),
      ]),
    );
  }

  Widget _buildKpiRow() {
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 900 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.2,
        children: [
          _kpiCard('Property Tax', '₹12.4L', Icons.currency_rupee_rounded, const Color(0xFF10B981), 'Collected this FY'),
          _kpiCard('Market Fees', '₹2.8L', Icons.storefront_rounded, const Color(0xFFF59E0B), '156 vendors'),
          _kpiCard('Asset Rental', '₹1.2L', Icons.domain_rounded, const Color(0xFF3B82F6), '8 active leases'),
          _kpiCard('Certificates', '48', Icons.description_rounded, const Color(0xFF8B5CF6), '12 pending review'),
        ],
      );
    });
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color, String sub) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 24),
        ),
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

  Widget _buildRevenueBreakdown() {
    final items = [
      {'source': 'Property Tax Collection', 'amount': '₹12,45,800', 'target': '₹20,00,000', 'pct': 0.62, 'color': const Color(0xFF10B981)},
      {'source': 'Market Stall Fees', 'amount': '₹2,81,500', 'target': '₹5,00,000', 'pct': 0.56, 'color': const Color(0xFFF59E0B)},
      {'source': 'Community Asset Rental', 'amount': '₹1,22,000', 'target': '₹2,00,000', 'pct': 0.61, 'color': const Color(0xFF3B82F6)},
      {'source': 'Ad Campaign Pole Leases', 'amount': '₹68,000', 'target': '₹1,50,000', 'pct': 0.45, 'color': const Color(0xFF8B5CF6)},
      {'source': 'Certificate Fees', 'amount': '₹24,000', 'target': '₹50,000', 'pct': 0.48, 'color': const Color(0xFFEF4444)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.pie_chart_rounded, color: Color(0xFF8B5CF6), size: 22),
          const SizedBox(width: 10),
          Text('Revenue Breakdown — FY 2025-26', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ]),
        const SizedBox(height: 16),
        ...items.map((i) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(i['source'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${i['amount']} / ${i['target']}', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: i['pct'] as double, backgroundColor: AppTheme.stroke,
                valueColor: AlwaysStoppedAnimation(i['color'] as Color), minHeight: 8,
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {'icon': Icons.currency_rupee_rounded, 'label': 'Property Tax', 'route': '/revenue/property-tax', 'color': const Color(0xFF10B981)},
      {'icon': Icons.storefront_rounded, 'label': 'Market Fees', 'route': '/revenue/markets', 'color': const Color(0xFFF59E0B)},
      {'icon': Icons.domain_rounded, 'label': 'Asset Rental', 'route': '/revenue/assets', 'color': const Color(0xFF3B82F6)},
      {'icon': Icons.ad_units_rounded, 'label': 'Ad Campaigns', 'route': '/revenue/ads', 'color': const Color(0xFF8B5CF6)},
      {'icon': Icons.task_alt_rounded, 'label': 'Certificates', 'route': '/revenue/certificates', 'color': const Color(0xFFEF4444)},
      {'icon': Icons.history_edu_rounded, 'label': 'Audit Logs', 'route': '/admin/audit-logs', 'color': const Color(0xFF64748B)},
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
            onTap: () => context.go(a['route'] as String), borderRadius: BorderRadius.circular(10),
            child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20), const SizedBox(width: 12),
                Text(a['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const Spacer(), Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
              ]),
            ),
          )),
        )),
      ]),
    );
  }

  Widget _buildAuditLog() {
    final logs = [
      {'action': 'Property tax payment ₹8,500 from Survey #142', 'time': '1 hour ago', 'icon': Icons.currency_rupee_rounded, 'color': const Color(0xFF10B981)},
      {'action': 'Market vendor Ravi - stall fee ₹200 collected', 'time': '3 hours ago', 'icon': Icons.storefront_rounded, 'color': const Color(0xFFF59E0B)},
      {'action': 'Community Hall booking approved for 15 Aug', 'time': '5 hours ago', 'icon': Icons.domain_rounded, 'color': const Color(0xFF3B82F6)},
      {'action': 'Ad lease agreement #PL-042 renewed for 12 months', 'time': '1 day ago', 'icon': Icons.ad_units_rounded, 'color': const Color(0xFF8B5CF6)},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.stroke)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Audit Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        const SizedBox(height: 16),
        ...logs.map((l) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (l['color'] as Color).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(l['icon'] as IconData, color: l['color'] as Color, size: 18)),
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
