import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class AssetMaintenanceLogScreen extends StatefulWidget {
  final String assetId;
  const AssetMaintenanceLogScreen({super.key, this.assetId = 'SL-MDU-Z3-042'});

  @override
  State<AssetMaintenanceLogScreen> createState() => _AssetMaintenanceLogScreenState();
}

class _AssetMaintenanceLogScreenState extends State<AssetMaintenanceLogScreen> {
  final List<Map<String, String>> _logs = [
    {
      'date': '10-Jan-2026',
      'type': 'Preventive Maintenance',
      'desc': 'Replaced 120W LED Driver unit & cleaned glass casing.',
      'cost': '₹ 1,800',
      'by': 'Tech Team A',
    },
    {
      'date': '14-Aug-2025',
      'type': 'Breakdown Repair',
      'desc': 'Fitted new junction box fuse after monsoon lightning surge.',
      'cost': '₹ 3,400',
      'by': 'TNEB Contractor',
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
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Maintenance Log History — ${widget.assetId}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Comprehensive preventive and breakdown maintenance records.'),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.build_rounded),
                label: const Text('Log Maintenance Event'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Maintenance Date')),
                  DataColumn(label: Text('Event Type')),
                  DataColumn(label: Text('Work Description')),
                  DataColumn(label: Text('Expense Cost (INR)')),
                  DataColumn(label: Text('Serviced By')),
                  DataColumn(label: Text('Receipt Invoice')),
                ],
                rows: _logs.map((l) {
                  return DataRow(
                    cells: [
                      DataCell(Text(l['date']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Chip(label: Text(l['type']!))),
                      DataCell(Text(l['desc']!)),
                      DataCell(Text(l['cost']!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(Text(l['by']!)),
                      DataCell(IconButton(icon: Icon(Icons.receipt_long_rounded, color: AppTheme.primary), onPressed: () {})),
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
