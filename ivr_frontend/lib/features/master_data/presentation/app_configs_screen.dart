import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class AppConfigsScreen extends StatefulWidget {
  const AppConfigsScreen({super.key});

  @override
  State<AppConfigsScreen> createState() => _AppConfigsScreenState();
}

class _AppConfigsScreenState extends State<AppConfigsScreen> {
  final List<Map<String, dynamic>> _configs = [
    {'key': 'storage.provider', 'value': 'aws_s3', 'type': 'String', 'scope': 'Tenant-Wide'},
    {'key': 'sms.gateway_url', 'value': 'https://api.sms.tn.gov.in/v2/send', 'type': 'String', 'scope': 'Tenant-Wide'},
    {'key': 'max_upload_size_mb', 'value': '25', 'type': 'Number', 'scope': 'Tenant-Wide'},
    {'key': 'offline_sync.max_queue_items', 'value': '500', 'type': 'Number', 'scope': 'Branch Scope'},
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
              Text('System AppConfig Dynamic Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton(onPressed: null, child: Text('Add AppConfig Key')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Runtime key-value configuration editor without redeploying code.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Config Key')),
                  DataColumn(label: Text('Config Value')),
                  DataColumn(label: Text('Value Type')),
                  DataColumn(label: Text('Branch Scope')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _configs.map((c) {
                  return DataRow(
                    cells: [
                      DataCell(Text(c['key'], style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                      DataCell(Text(c['value'])),
                      DataCell(Chip(label: Text(c['type']))),
                      DataCell(Chip(label: Text(c['scope']))),
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
