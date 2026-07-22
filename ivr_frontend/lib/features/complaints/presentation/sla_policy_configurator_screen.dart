import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class SlaPolicyConfiguratorScreen extends StatefulWidget {
  const SlaPolicyConfiguratorScreen({super.key});

  @override
  State<SlaPolicyConfiguratorScreen> createState() => _SlaPolicyConfiguratorScreenState();
}

class _SlaPolicyConfiguratorScreenState extends State<SlaPolicyConfiguratorScreen> {
  final List<Map<String, dynamic>> _policies = [
    {
      'category': 'Electrical Fault',
      'urgency': 'Critical',
      'targetHours': 24,
      'warningHours': 18,
      'escalateRole': 'Assistant Executive Engineer',
      'emergencyOverride': true,
    },
    {
      'category': 'Road Pothole',
      'urgency': 'Medium',
      'targetHours': 72,
      'warningHours': 48,
      'escalateRole': 'Junior Engineer',
      'emergencyOverride': false,
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
              Text('SLA Policy & Rule Configurator (SlaPolicy)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton(onPressed: null, child: Text('Add SLA Policy')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Configure resolution target business hours, warning thresholds, auto-escalation pathways.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Complaint Category')),
                  DataColumn(label: Text('Urgency Level')),
                  DataColumn(label: Text('Target Business Hrs')),
                  DataColumn(label: Text('Warning Threshold')),
                  DataColumn(label: Text('Auto-Escalate Role')),
                  DataColumn(label: Text('24x7 Emergency Override')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _policies.map((p) {
                  return DataRow(
                    cells: [
                      DataCell(Text(p['category'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Chip(label: Text(p['urgency']))),
                      DataCell(Text('${p['targetHours']} Hours')),
                      DataCell(Text('${p['warningHours']} Hours')),
                      DataCell(Text(p['escalateRole'])),
                      DataCell(Switch(value: p['emergencyOverride'], onChanged: (val) {})),
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
