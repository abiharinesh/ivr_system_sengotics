import 'package:flutter/material.dart';

class OfflineSyncCenterScreen extends StatefulWidget {
  const OfflineSyncCenterScreen({super.key});

  @override
  State<OfflineSyncCenterScreen> createState() => _OfflineSyncCenterScreenState();
}

class _OfflineSyncCenterScreenState extends State<OfflineSyncCenterScreen> {
  final List<Map<String, String>> _queue = [
    {'type': 'Inspection Audit', 'ref': 'SL-MDU-Z3-042', 'time': '10 mins ago', 'status': 'Pending'},
    {'type': 'Grievance Resolution', 'ref': 'CMP-2026-000042', 'time': '25 mins ago', 'status': 'Pending'},
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Offline Sync Queue & Conflict Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('SQLite local storage sync status and server vs local conflict resolver.'),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sync_rounded),
                label: const Text('Sync All Now'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Record Type')),
                  DataColumn(label: Text('Reference Code')),
                  DataColumn(label: Text('Created Offline At')),
                  DataColumn(label: Text('Sync Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _queue.map((q) {
                  return DataRow(
                    cells: [
                      DataCell(Text(q['type']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(q['ref']!)),
                      DataCell(Text(q['time']!)),
                      DataCell(Chip(label: Text(q['status']!), backgroundColor: Colors.amber.shade100)),
                      DataCell(OutlinedButton(onPressed: () {}, child: const Text('Sync Now'))),
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
