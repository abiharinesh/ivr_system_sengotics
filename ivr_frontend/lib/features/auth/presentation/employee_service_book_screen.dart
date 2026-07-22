import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class EmployeeServiceBookScreen extends StatefulWidget {
  const EmployeeServiceBookScreen({super.key});

  @override
  State<EmployeeServiceBookScreen> createState() => _EmployeeServiceBookScreenState();
}

class _EmployeeServiceBookScreenState extends State<EmployeeServiceBookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.stroke),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    'KR',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'K. Rajasekar',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Employee Code: EMP-00042 • Cadre: TNCS • Pay Level: 14',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Service Book No: SB/TN/2012/89402 • Executive Level 7',
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export e-Service Book (PDF)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.primary,
              tabs: const [
                Tab(text: 'Posting & Personal'),
                Tab(text: 'Designation History Timeline'),
                Tab(text: 'Hierarchy & Subordinates'),
                Tab(text: 'Granted Permissions Matrix'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPostingTab(),
                _buildHistoryTimelineTab(),
                _buildHierarchyTab(),
                _buildPermissionsMatrixTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostingTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            ListTile(
              title: const Text('Current Department'),
              subtitle: const Text('General Administration & Local Self Government'),
              leading: Icon(Icons.business_rounded, color: AppTheme.primary),
            ),
            const Divider(),
            ListTile(
              title: const Text('Designation'),
              subtitle: const Text('Block Development Officer (BDO)'),
              leading: Icon(Icons.badge_rounded, color: AppTheme.primary),
            ),
            const Divider(),
            ListTile(
              title: const Text('Date of First Joining'),
              subtitle: const Text('14-May-2012 (14 Years, 2 Months Service)'),
              leading: Icon(Icons.calendar_today_rounded, color: AppTheme.primary),
            ),
            const Divider(),
            ListTile(
              title: const Text('Superannuation / Retirement Date'),
              subtitle: const Text('31-May-2038 (11 Years Remaining)'),
              leading: Icon(Icons.event_available_rounded, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTimelineTab() {
    final history = [
      {
        'date': '01-Apr-2024 to Present',
        'title': 'Block Development Officer (BDO)',
        'location': 'Usilampatti Panchayat Union',
        'goNum': 'G.O. Ms. No. 142/RD&PR',
      },
      {
        'date': '15-Jan-2021 to 31-Mar-2024',
        'title': 'Assistant Development Officer',
        'location': 'Thirumangalam Panchayat Union',
        'goNum': 'G.O. Ms. No. 89/RD&PR',
      },
      {
        'date': '14-May-2012 to 14-Jan-2021',
        'title': 'Junior Assistant / Accountant',
        'location': 'Madurai Collectorate',
        'goNum': 'G.O. Ms. No. 12/RD&PR',
      },
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (index < history.length - 1)
                      Container(
                        width: 2,
                        height: 70,
                        color: AppTheme.stroke,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${item['location']} • ${item['date']}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ref: ${item['goNum']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHierarchyTab() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: const [
            Text(
              'Reporting Supervisor',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(child: Text('DR')),
              title: Text('District Collector & District Magistrate'),
              subtitle: Text('Madurai District Collectorate'),
            ),
            Divider(height: 32),
            Text(
              'Direct Subordinate Team (5 Staff)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            ListTile(
              leading: CircleAvatar(child: Text('PS')),
              title: Text('Panchayat Secretary — Usilampatti'),
              subtitle: Text('Panchayat Admin Cadre'),
            ),
            ListTile(
              leading: CircleAvatar(child: Text('JE')),
              title: Text('Junior Engineer — Rural Works'),
              subtitle: Text('Engineering Wing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsMatrixTab() {
    final permissions = [
      {'code': 'complaints.approve', 'desc': 'Approve Grievance Resolutions', 'status': 'Granted'},
      {'code': 'workorders.issue', 'desc': 'Issue Work Orders up to ₹10 Lakhs', 'status': 'Granted'},
      {'code': 'tenders.evaluate', 'desc': 'Evaluate Technical Bids', 'status': 'Granted'},
      {'code': 'assets.decommission', 'desc': 'Decommission Ward Assets', 'status': 'Denied'},
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Permission Code')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Status')),
          ],
          rows: permissions.map((p) {
            final isGranted = p['status'] == 'Granted';
            return DataRow(
              cells: [
                DataCell(Text(p['code']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(p['desc']!)),
                DataCell(
                  Chip(
                    label: Text(p['status']!),
                    backgroundColor: isGranted ? Colors.green.shade50 : Colors.red.shade50,
                    labelStyle: TextStyle(
                      color: isGranted ? Colors.green.shade800 : Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
