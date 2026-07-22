import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class WorkflowTemplateBuilderScreen extends StatefulWidget {
  const WorkflowTemplateBuilderScreen({super.key});

  @override
  State<WorkflowTemplateBuilderScreen> createState() => _WorkflowTemplateBuilderScreenState();
}

class _WorkflowTemplateBuilderScreenState extends State<WorkflowTemplateBuilderScreen> {
  final List<Map<String, String>> _nodes = [
    {'step': 'Step 1', 'role': 'Junior Engineer (JE)', 'timeout': '24 Hours'},
    {'step': 'Step 2', 'role': 'Assistant Executive Engineer (AEE)', 'timeout': '48 Hours'},
    {'step': 'Step 3', 'role': 'Municipal Commissioner', 'timeout': '72 Hours'},
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
              Text('Workflow Template Visual Builder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton(onPressed: null, child: Text('Save Template Schema')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Design sequential or parallel approval workflows for work orders, tenders, and permits.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: TextFormField(initialValue: 'Work Order Approval Chain', decoration: const InputDecoration(labelText: 'Workflow Name'))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: 'work_order',
                          decoration: const InputDecoration(labelText: 'Target Module Entity'),
                          items: const [
                            DropdownMenuItem(value: 'work_order', child: Text('Work Orders')),
                            DropdownMenuItem(value: 'tenders', child: Text('Tenders & Procurement')),
                            DropdownMenuItem(value: 'permits', child: Text('Building Permits')),
                          ],
                          onChanged: (v) {},
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _nodes.map((node) {
                      return Row(
                        children: [
                          Container(
                            width: 220,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary),
                            ),
                            child: Column(
                              children: [
                                Text(node['step']!, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                                const SizedBox(height: 6),
                                Text(node['role']!, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Timeout: ${node['timeout']}', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          if (node['step'] != 'Step 3')
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.arrow_forward_rounded, color: AppTheme.primary, size: 28),
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
}
