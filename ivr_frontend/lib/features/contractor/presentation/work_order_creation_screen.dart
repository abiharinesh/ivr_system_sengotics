import 'package:flutter/material.dart';

class WorkOrderCreationScreen extends StatefulWidget {
  const WorkOrderCreationScreen({super.key});

  @override
  State<WorkOrderCreationScreen> createState() => _WorkOrderCreationScreenState();
}

class _WorkOrderCreationScreenState extends State<WorkOrderCreationScreen> {
  final List<Map<String, String>> _milestones = [
    {'name': 'Milestone 1: Site Clearing & Excavation', 'pct': '20%', 'amt': '₹ 1,50,000'},
    {'name': 'Milestone 2: Sub-structure Concreting', 'pct': '40%', 'amt': '₹ 3,00,000'},
    {'name': 'Milestone 3: Final Handover & Testing', 'pct': '40%', 'amt': '₹ 3,00,000'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sanction Work Order & Set Milestones', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Issue sanctioned civil/maintenance work orders to empanelled contractors.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: TextFormField(initialValue: 'WO-2026-000042', decoration: const InputDecoration(labelText: 'Work Order Code'))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: 'M/s Sengotics Infrastructure Pvt Ltd',
                          decoration: const InputDecoration(labelText: 'Empanelled Contractor'),
                          items: const [
                            DropdownMenuItem(value: 'M/s Sengotics Infrastructure Pvt Ltd', child: Text('M/s Sengotics Infra (Class I)')),
                            DropdownMenuItem(value: 'M/s Tamil Civil Builders', child: Text('M/s Tamil Civil Builders (Class II)')),
                          ],
                          onChanged: (v) {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Sanctioned Total Amount (₹ INR)'))),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(decoration: const InputDecoration(labelText: 'Budget Head Code (e.g. 2217-104-01)'))),
                    ],
                  ),
                  const Divider(height: 36),
                  const Text('Payment Release Milestones Builder Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Milestone Name')),
                      DataColumn(label: Text('Release %')),
                      DataColumn(label: Text('Financial Release Amount')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _milestones.map((m) {
                      return DataRow(
                        cells: [
                          DataCell(Text(m['name']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(m['pct']!)),
                          DataCell(Text(m['amt']!)),
                          DataCell(IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {})),
                        ],
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Issue Sanctioned Work Order'),
                    ),
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
