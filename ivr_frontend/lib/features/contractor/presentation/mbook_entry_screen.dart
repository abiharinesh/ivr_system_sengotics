import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class MBookEntryScreen extends StatefulWidget {
  final String workOrderId;
  const MBookEntryScreen({super.key, this.workOrderId = 'WO-2026-000042'});

  @override
  State<MBookEntryScreen> createState() => _MBookEntryScreenState();
}

class _MBookEntryScreenState extends State<MBookEntryScreen> {
  final List<Map<String, dynamic>> _mbookItems = [
    {
      'ref': 'DSR Item 4.1.2',
      'desc': 'Concreting M20 Grade for Foundation',
      'n': 4,
      'l': 10.5,
      'b': 2.0,
      'd': 1.2,
      'totalQty': '100.8 cu.m',
      'rate': '₹ 4,500',
      'amount': '₹ 4,53,600',
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
                  Text('Digital Measurement Book (M-Book) — ${widget.workOrderId}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const Text('Record site physical measurements and verification chain (JE → AEE → Accounts).'),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Measurement Line Item'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Item Code')),
                  DataColumn(label: Text('Description')),
                  DataColumn(label: Text('No (N)')),
                  DataColumn(label: Text('L')),
                  DataColumn(label: Text('B')),
                  DataColumn(label: Text('D')),
                  DataColumn(label: Text('Calculated Qty')),
                  DataColumn(label: Text('Total Amount')),
                  DataColumn(label: Text('Photo Proof')),
                ],
                rows: _mbookItems.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item['ref'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(item['desc'])),
                      DataCell(Text('${item['n']}')),
                      DataCell(Text('${item['l']}')),
                      DataCell(Text('${item['b']}')),
                      DataCell(Text('${item['d']}')),
                      DataCell(Text(item['totalQty'], style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(item['amount'], style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                      DataCell(IconButton(icon: Icon(Icons.photo_camera, color: AppTheme.primary), onPressed: () {})),
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
