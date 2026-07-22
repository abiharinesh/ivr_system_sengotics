import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class BranchLifecycleScreen extends StatefulWidget {
  final String branchId;
  const BranchLifecycleScreen({super.key, this.branchId = 'USL-BLK-12'});

  @override
  State<BranchLifecycleScreen> createState() => _BranchLifecycleScreenState();
}

class _BranchLifecycleScreenState extends State<BranchLifecycleScreen> {
  String _selectedStatus = 'ACTIVE';

  final List<Map<String, String>> _lifecycleLogs = [
    {
      'date': '12-Jan-2026',
      'from': 'VILLAGE_PANCHAYAT',
      'to': 'TOWN_PANCHAYAT (Upgraded)',
      'by': 'Super Admin (EMP-00001)',
      'go': 'G.O. Ms. No. 45/RD&PR',
      'reason': 'Population threshold crossed > 20,000 as per 2025 Census Survey.',
    },
    {
      'date': '01-Apr-2020',
      'from': 'DRAFT',
      'to': 'ACTIVE',
      'by': 'State Admin',
      'go': 'G.O. Ms. No. 12/RD&PR',
      'reason': 'Initial Gazette notification and administrative setup.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.stroke),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.account_tree_rounded, color: AppTheme.primary, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usilampatti Panchayat Union (${widget.branchId})',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Current Level: Level 3 (Panchayat Union) • Parent: Madurai District Panchayat',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('Current Status: $_selectedStatus'),
                  backgroundColor: Colors.green.shade100,
                  labelStyle: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Status Action Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Administrative Transition & Lifecycle Action',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(labelText: 'Target Status Action'),
                          items: const [
                            DropdownMenuItem(value: 'ACTIVE', child: Text('Maintain Active')),
                            DropdownMenuItem(value: 'UPGRADED', child: Text('Upgrade to Municipality')),
                            DropdownMenuItem(value: 'MERGED', child: Text('Merge with Neighboring Union')),
                            DropdownMenuItem(value: 'CLOSED', child: Text('Administrative Closure')),
                          ],
                          onChanged: (v) => setState(() => _selectedStatus = v!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Government Order Reference (G.O. No)',
                            hintText: 'e.g. G.O. Ms. No. 104/RD&PR',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Status Change Rationale & Operational Impact Notes',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Branch Lifecycle Event Submitted Successfully!')),
                        );
                      },
                      icon: const Icon(Icons.published_with_changes_rounded),
                      label: const Text('Execute Transition & Gazette Log'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Timeline Log Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historical Lifecycle Event Log (BranchLifecycleEvent)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Effective Date')),
                      DataColumn(label: Text('Previous State')),
                      DataColumn(label: Text('New Transition State')),
                      DataColumn(label: Text('G.O. Reference')),
                      DataColumn(label: Text('Executed By')),
                    ],
                    rows: _lifecycleLogs.map((log) {
                      return DataRow(
                        cells: [
                          DataCell(Text(log['date']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(log['from']!)),
                          DataCell(Chip(label: Text(log['to']!))),
                          DataCell(Text(log['go']!, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
                          DataCell(Text(log['by']!)),
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
}
