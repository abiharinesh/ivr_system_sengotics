import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class AssetInventoryScreen extends StatefulWidget {
  const AssetInventoryScreen({super.key});

  @override
  State<AssetInventoryScreen> createState() => _AssetInventoryScreenState();
}

class _AssetInventoryScreenState extends State<AssetInventoryScreen> {
  final List<Map<String, dynamic>> _assets = [
    {
      'code': 'SL-MDU-Z3-042',
      'name': 'Smart LED Pole #42',
      'category': 'Street Light',
      'branch': 'Madurai Corp Zone 3',
      'status': 'Operational',
      'health': '94%',
    },
    {
      'code': 'WP-THM-012',
      'name': 'Main Water Pump Station 12',
      'category': 'Water Pump',
      'branch': 'Usilampatti Union',
      'status': 'Maintenance Required',
      'health': '58%',
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Municipal Physical Asset Inventory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Register, track, inspect, and maintain municipal infrastructure assets.'),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Register New Asset'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKpi('Total Tracked Assets', '4,850 Units', Icons.inventory_2_rounded, Colors.blue),
              const SizedBox(width: 16),
              _buildKpi('Operational Health', '91.8% Normal', Icons.health_and_safety_rounded, Colors.green),
              const SizedBox(width: 16),
              _buildKpi('Pending Inspections', '34 Due Today', Icons.build_circle_rounded, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search by asset code, name, category, or branch location...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Asset Code')),
                      DataColumn(label: Text('Asset Display Name')),
                      DataColumn(label: Text('Category Type')),
                      DataColumn(label: Text('Active Branch Location')),
                      DataColumn(label: Text('Operational Status')),
                      DataColumn(label: Text('Health Score')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _assets.map((a) {
                      return DataRow(
                        cells: [
                          DataCell(Text(a['code'], style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(a['name'])),
                          DataCell(Chip(label: Text(a['category']))),
                          DataCell(Text(a['branch'])),
                          DataCell(Chip(label: Text(a['status']))),
                          DataCell(Text(a['health'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
                          DataCell(
                            Row(
                              children: [
                                IconButton(icon: Icon(Icons.qr_code_rounded, color: AppTheme.primary), onPressed: () {}),
                                IconButton(icon: const Icon(Icons.history_rounded), onPressed: () {}),
                              ],
                            ),
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

  Widget _buildKpi(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
