import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  State<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  final List<Map<String, dynamic>> _tenants = [
    {
      'id': 'tn_govt',
      'name': 'Tamil Nadu e-Governance Administration',
      'domain': 'tn.platform.gov.in',
      'plan': 'Enterprise State Tier',
      'maxBranches': 12500,
      'status': 'Active',
    },
    {
      'id': 'mdu_corp',
      'name': 'Madurai City Municipal Corporation',
      'domain': 'maduraicorp.tn.gov.in',
      'plan': 'Municipal Corp Tier',
      'maxBranches': 100,
      'status': 'Active',
    },
    {
      'id': 'cbe_corp',
      'name': 'Coimbatore Municipal Corporation',
      'domain': 'coimbatorecorp.tn.gov.in',
      'plan': 'Municipal Corp Tier',
      'maxBranches': 100,
      'status': 'Active',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multi-Tenant Administration',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage state deployments, tenant limits, subdomains, and feature licenses.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showCreateTenantModal,
                icon: const Icon(Icons.add_business_rounded),
                label: const Text('Add State Tenant'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Metric Cards
          Row(
            children: [
              _buildKpiCard('Total Tenants', '3 Active', Icons.domain_rounded, Colors.blue),
              const SizedBox(width: 16),
              _buildKpiCard('Total Managed Branches', '12,700 Branches', Icons.account_tree_rounded, Colors.purple),
              const SizedBox(width: 16),
              _buildKpiCard('Active System Users', '48,920 Users', Icons.group_rounded, Colors.green),
            ],
          ),
          const SizedBox(height: 24),
          // Tenants Data Table Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tenants by name or domain...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Tenant ID')),
                      DataColumn(label: Text('Tenant Name')),
                      DataColumn(label: Text('Custom Domain')),
                      DataColumn(label: Text('Subscription Tier')),
                      DataColumn(label: Text('Max Branches')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _tenants.map((t) {
                      return DataRow(
                        cells: [
                          DataCell(Text(t['id'], style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(t['name'])),
                          DataCell(Text(t['domain'])),
                          DataCell(Chip(label: Text(t['plan']))),
                          DataCell(Text('${t['maxBranches']}')),
                          DataCell(
                            Chip(
                              label: Text(t['status']),
                              backgroundColor: Colors.green.shade100,
                              labelStyle: TextStyle(color: Colors.green.shade800),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: Icon(Icons.edit_rounded, color: AppTheme.primary),
                              onPressed: () {},
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTenantModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New State Tenant'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(decoration: const InputDecoration(labelText: 'Tenant ID (e.g. tn_govt)')),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Tenant Display Name')),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Custom Domain')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Create Tenant')),
        ],
      ),
    );
  }
}
