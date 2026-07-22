import 'package:flutter/material.dart';

class AuditLogInspectorScreen extends StatefulWidget {
  const AuditLogInspectorScreen({super.key});

  @override
  State<AuditLogInspectorScreen> createState() => _AuditLogInspectorScreenState();
}

class _AuditLogInspectorScreenState extends State<AuditLogInspectorScreen> {
  final List<Map<String, String>> _logs = [
    {'time': '2026-07-22 14:22', 'user': 'K. Rajasekar (EMP-00042)', 'action': 'APPROVE_WORK_ORDER', 'ip': '10.0.4.12', 'entity': 'WO-2026-000012'},
    {'time': '2026-07-22 12:10', 'user': 'S. Meenakshi (EMP-00089)', 'action': 'CREATE_ASSET', 'ip': '10.0.4.88', 'entity': 'SL-MDU-Z3-042'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tamper-Evident System Audit Trail Inspector', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Immutable event logs capturing IP addresses, timestamps, actor IDs, and cryptographic SHA-256 hashes.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Timestamp')),
                  DataColumn(label: Text('Actor / User')),
                  DataColumn(label: Text('Action Type')),
                  DataColumn(label: Text('Target Entity')),
                  DataColumn(label: Text('IP Address')),
                ],
                rows: _logs.map((l) {
                  return DataRow(
                    cells: [
                      DataCell(Text(l['time']!, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                      DataCell(Text(l['user']!)),
                      DataCell(Chip(label: Text(l['action']!))),
                      DataCell(Text(l['entity']!)),
                      DataCell(Text(l['ip']!, style: const TextStyle(fontFamily: 'monospace'))),
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
