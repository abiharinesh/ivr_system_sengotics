import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  final List<Map<String, String>> _employees = [
    {
      'code': 'EMP-00042',
      'name': 'K. Rajasekar',
      'cadre': 'TNCS',
      'dept': 'General Administration',
      'designation': 'Block Development Officer',
      'branch': 'Usilampatti Panchayat Union',
      'status': 'Active',
    },
    {
      'code': 'EMP-00089',
      'name': 'S. Meenakshi',
      'cadre': 'TNEB',
      'dept': 'Electrical & Lighting',
      'designation': 'Assistant Executive Engineer',
      'branch': 'Madurai Corporation Zone 3',
      'status': 'Active',
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
                  Text('Employee Directory & Service Profiles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Official directory of empanelled government staff across departments.'),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Onboard Employee'),
              ),
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
                      hintText: 'Search by employee code, name, designation, or branch...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Emp Code')),
                      DataColumn(label: Text('Employee Name')),
                      DataColumn(label: Text('Cadre / Dept')),
                      DataColumn(label: Text('Designation')),
                      DataColumn(label: Text('Active Branch Posting')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _employees.map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text(e['code']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(e['name']!)),
                          DataCell(Text('${e['cadre']} • ${e['dept']}')),
                          DataCell(Text(e['designation']!)),
                          DataCell(Text(e['branch']!)),
                          DataCell(Chip(label: Text(e['status']!), backgroundColor: Colors.green.shade100)),
                          DataCell(
                            Row(
                              children: [
                                IconButton(icon: Icon(Icons.history_rounded, color: AppTheme.primary), onPressed: () {}),
                                IconButton(icon: const Icon(Icons.badge_outlined), onPressed: () {}),
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
}
