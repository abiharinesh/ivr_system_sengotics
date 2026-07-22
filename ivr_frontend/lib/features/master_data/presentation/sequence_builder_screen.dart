import 'package:flutter/material.dart';

class SequenceBuilderScreen extends StatefulWidget {
  const SequenceBuilderScreen({super.key});

  @override
  State<SequenceBuilderScreen> createState() => _SequenceBuilderScreenState();
}

class _SequenceBuilderScreenState extends State<SequenceBuilderScreen> {
  final List<Map<String, dynamic>> _sequences = [
    {
      'entity': 'complaint',
      'prefix': 'CMP',
      'pattern': '{prefix}-{fy}-{seq:6}',
      'preview': 'CMP-2026-000042',
      'currentSeq': 42,
      'resetCycle': 'financial_year',
    },
    {
      'entity': 'work_order',
      'prefix': 'WO',
      'pattern': '{prefix}-{branch}-{seq:4}',
      'preview': 'WO-USL-0014',
      'currentSeq': 14,
      'resetCycle': 'calendar_year',
    },
    {
      'entity': 'tender',
      'prefix': 'TEN',
      'pattern': '{prefix}-{fy}-{seq:5}',
      'preview': 'TEN-2026-00008',
      'currentSeq': 8,
      'resetCycle': 'never',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Number Generation Sequence Builder (SequenceConfig)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              ElevatedButton(onPressed: null, child: Text('Add New Sequence')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Configure automated document number generation formats across entities.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Entity Type')),
                  DataColumn(label: Text('Prefix')),
                  DataColumn(label: Text('Pattern Format')),
                  DataColumn(label: Text('Live Pattern Preview')),
                  DataColumn(label: Text('Counter')),
                  DataColumn(label: Text('Reset Cycle')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _sequences.map((s) {
                  return DataRow(
                    cells: [
                      DataCell(Text(s['entity'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(s['prefix'])),
                      DataCell(Text(s['pattern'])),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade300),
                          ),
                          child: Text(
                            s['preview'],
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text('${s['currentSeq']}')),
                      DataCell(Chip(label: Text(s['resetCycle']))),
                      DataCell(IconButton(icon: const Icon(Icons.tune), onPressed: () {})),
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
