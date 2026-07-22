import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class ConditionalApprovalMatrixScreen extends StatefulWidget {
  const ConditionalApprovalMatrixScreen({super.key});

  @override
  State<ConditionalApprovalMatrixScreen> createState() => _ConditionalApprovalMatrixScreenState();
}

class _ConditionalApprovalMatrixScreenState extends State<ConditionalApprovalMatrixScreen> {
  final List<Map<String, dynamic>> _rules = [
    {
      'field': 'estimated_cost',
      'operator': '>',
      'val': '₹ 5,00,000',
      'action': 'Add Mandatory Higher Step',
      'target': 'District Collector Sanction',
    },
    {
      'field': 'urgency_level',
      'operator': '==',
      'val': 'Emergency',
      'action': 'Bypass Intermediate Step',
      'target': 'Direct Executive Engineer Approval',
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
            children: const [
              Text('Conditional Routing Matrix Builder (WorkflowRule)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton(onPressed: null, child: Text('Add Conditional Rule')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Modify approval routing based on cost thresholds or urgency parameters.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Condition Field')),
                  DataColumn(label: Text('Operator')),
                  DataColumn(label: Text('Value Threshold')),
                  DataColumn(label: Text('Routing Action')),
                  DataColumn(label: Text('Target Role / Step')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _rules.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(r['field'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                      DataCell(Text(r['operator'])),
                      DataCell(Text(r['val'])),
                      DataCell(Chip(label: Text(r['action']))),
                      DataCell(Text(r['target'])),
                      DataCell(IconButton(icon: Icon(Icons.edit, color: AppTheme.primary), onPressed: () {})),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
