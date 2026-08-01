import 'package:flutter/material.dart';

class DynamicReportBuilderScreen extends StatefulWidget {
  const DynamicReportBuilderScreen({super.key});

  @override
  State<DynamicReportBuilderScreen> createState() => _DynamicReportBuilderScreenState();
}

class _DynamicReportBuilderScreenState extends State<DynamicReportBuilderScreen> {
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
                  Text('Dynamic Report Builder & Export Engine', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Construct custom query reports with scheduled PDF/Excel email export.'),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf), label: const Text('Export PDF')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.table_view), label: const Text('Export Excel (.xlsx)')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: 'Complaints',
                    decoration: const InputDecoration(labelText: 'Data Source Collection'),
                    items: const [
                      DropdownMenuItem(value: 'Complaints', child: Text('Complaints & Grievances')),
                      DropdownMenuItem(value: 'Assets', child: Text('Municipal Assets Register')),
                      DropdownMenuItem(value: 'WorkOrders', child: Text('Work Orders & M-Book')),
                    ],
                    onChanged: (v) {},
                  ),
                  const SizedBox(height: 20),
                  const Text('Sample Report Data Live Preview Grid', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Record ID')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Ward Number')),
                      DataColumn(label: Text('SLA Resolution Status')),
                    ],
                    rows: const [
                      DataRow(cells: [DataCell(Text('CMP-001')), DataCell(Text('Electrical')), DataCell(Text('Ward 14')), DataCell(Text('Resolved'))]),
                      DataRow(cells: [DataCell(Text('CMP-002')), DataCell(Text('Water Pump')), DataCell(Text('Ward 08')), DataCell(Text('Pending'))]),
                    ],
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
