import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class UserRoleAssignmentScreen extends StatefulWidget {
  const UserRoleAssignmentScreen({super.key});

  @override
  State<UserRoleAssignmentScreen> createState() => _UserRoleAssignmentScreenState();
}

class _UserRoleAssignmentScreenState extends State<UserRoleAssignmentScreen> {
  final List<Map<String, String>> _assignments = [
    {
      'user': 'K. Rajasekar (EMP-00042)',
      'role': 'Block Development Officer (BDO)',
      'branch': 'Usilampatti Panchayat Union',
      'scope': 'all_branches',
    },
    {
      'user': 'S. Meenakshi (EMP-00089)',
      'role': 'Assistant Executive Engineer',
      'branch': 'Madurai Corporation Zone 3',
      'scope': 'child_branches',
    },
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
              Text('User Role & Branch Assignment Manager', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton(onPressed: null, child: Text('Assign New Role Context')),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Assign RBAC role groups and branch access scopes to employees.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Employee / User')),
                  DataColumn(label: Text('Assigned Role Group')),
                  DataColumn(label: Text('Target Branch Posting')),
                  DataColumn(label: Text('Access Scope Scope')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _assignments.map((a) {
                  return DataRow(
                    cells: [
                      DataCell(Text(a['user']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Chip(label: Text(a['role']!))),
                      DataCell(Text(a['branch']!)),
                      DataCell(Chip(label: Text(a['scope']!))),
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
