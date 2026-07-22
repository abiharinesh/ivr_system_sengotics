import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class MasterDataConfiguratorScreen extends StatefulWidget {
  const MasterDataConfiguratorScreen({super.key});

  @override
  State<MasterDataConfiguratorScreen> createState() => _MasterDataConfiguratorScreenState();
}

class _MasterDataConfiguratorScreenState extends State<MasterDataConfiguratorScreen> {
  String _selectedCategory = 'complaint_category';

  final List<Map<String, String>> _categories = [
    {'code': 'complaint_category', 'name': 'Grievance Categories'},
    {'code': 'asset_category', 'name': 'Municipal Asset Types'},
    {'code': 'department', 'name': 'Government Departments'},
    {'code': 'priority', 'name': 'SLA Priority Levels'},
    {'code': 'holiday_type', 'name': 'Calendar Holiday Types'},
  ];

  final List<Map<String, dynamic>> _masterValues = [
    {
      'code': 'electrical_fault',
      'nameEn': 'Electrical & Street Light Fault',
      'nameTa': 'மின் பழுது மற்றும் தெருவிளக்கு',
      'order': 1,
      'protected': true,
      'active': true,
    },
    {
      'code': 'water_leakage',
      'nameEn': 'Water Pipe Leakage / Burst',
      'nameTa': 'குடிநீர் குழாய் கசிவு',
      'order': 2,
      'protected': false,
      'active': true,
    },
    {
      'code': 'road_pothole',
      'nameEn': 'Road Pothole & Patchwork',
      'nameTa': 'சாலை பழுது மற்றும் குழி',
      'order': 3,
      'protected': false,
      'active': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar category list
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(right: BorderSide(color: AppTheme.stroke)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Master Lookup Categories',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final item = _categories[index];
                      final isSelected = _selectedCategory == item['code'];
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        title: Text(
                          item['name']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(item['code']!, style: const TextStyle(fontSize: 11)),
                        onTap: () => setState(() => _selectedCategory = item['code']!),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Values data table
          Expanded(
            child: Padding(
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
                          Text(
                            'Master Category: $_selectedCategory',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text('Dynamic lookup tables and Tamil translations'),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showAddValueDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Lookup Value'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Lookup Code')),
                          DataColumn(label: Text('English Display Name')),
                          DataColumn(label: Text('Tamil Translation (தமிழ்)')),
                          DataColumn(label: Text('Display Order')),
                          DataColumn(label: Text('System Protected')),
                          DataColumn(label: Text('Active')),
                        ],
                        rows: _masterValues.map((v) {
                          return DataRow(
                            cells: [
                              DataCell(Text(v['code'], style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(v['nameEn'])),
                              DataCell(Text(v['nameTa'], style: const TextStyle(fontFamily: 'NotoSansTamil'))),
                              DataCell(Text('${v['order']}')),
                              DataCell(
                                Chip(
                                  label: Text(v['protected'] ? 'Protected' : 'Custom'),
                                  backgroundColor: v['protected'] ? Colors.orange.shade50 : Colors.blue.shade50,
                                ),
                              ),
                              DataCell(Switch(value: v['active'], onChanged: (val) {})),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddValueDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Master Lookup Value'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(decoration: const InputDecoration(labelText: 'Lookup Code (e.g. electrical_fault)')),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'English Name')),
            const SizedBox(height: 12),
            TextFormField(decoration: const InputDecoration(labelText: 'Tamil Translation (தமிழ்)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Save Lookup Value')),
        ],
      ),
    );
  }
}
