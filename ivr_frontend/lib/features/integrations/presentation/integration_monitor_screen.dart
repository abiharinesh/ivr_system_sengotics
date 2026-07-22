import 'package:flutter/material.dart';

class IntegrationMonitorScreen extends StatefulWidget {
  const IntegrationMonitorScreen({super.key});

  @override
  State<IntegrationMonitorScreen> createState() => _IntegrationMonitorScreenState();
}

class _IntegrationMonitorScreenState extends State<IntegrationMonitorScreen> {
  final List<Map<String, String>> _integrations = [
    {'name': 'TANGEDCO Electricity Board API', 'type': 'REST API', 'cron': 'Every 1 Hour', 'status': 'Active'},
    {'name': 'TWAD Water Supply Feed', 'type': 'SOAP Web Service', 'cron': '0 2 * * *', 'status': 'Active'},
    {'name': 'DigiLocker Verification Gateway', 'type': 'REST API', 'cron': 'Realtime Webhook', 'status': 'Active'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Integration & Webhook Monitor (IntegrationConfig)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Monitor third-party state API feeds (TANGEDCO, TWAD, DigiLocker) and webhook retries.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Integration Name')),
                  DataColumn(label: Text('Protocol Type')),
                  DataColumn(label: Text('Cron Sync Schedule')),
                  DataColumn(label: Text('Connection Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _integrations.map((i) {
                  return DataRow(
                    cells: [
                      DataCell(Text(i['name']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Chip(label: Text(i['type']!))),
                      DataCell(Text(i['cron']!)),
                      DataCell(Chip(label: Text(i['status']!), backgroundColor: Colors.green.shade100)),
                      DataCell(OutlinedButton(onPressed: () {}, child: const Text('Retry Webhook'))),
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
