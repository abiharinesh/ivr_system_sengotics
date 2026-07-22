import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class EmployeeGrievanceKanbanScreen extends StatefulWidget {
  const EmployeeGrievanceKanbanScreen({super.key});

  @override
  State<EmployeeGrievanceKanbanScreen> createState() => _EmployeeGrievanceKanbanScreenState();
}

class _EmployeeGrievanceKanbanScreenState extends State<EmployeeGrievanceKanbanScreen> {
  final List<String> _columns = [
    'New Registered',
    'Assigned',
    'In Progress',
    'Pending Verification',
    'Resolved',
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
            children: const [
              Text('Grievance Kanban Workbench & Live SLA Timers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Chip(label: Text('Live SLA Business Hour Calculations Active'), backgroundColor: Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 600,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _columns.length,
              itemBuilder: (context, index) {
                final colTitle = _columns[index];
                return Container(
                  width: 320,
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(colTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primary,
                            child: const Text('2', style: TextStyle(fontSize: 11, color: Colors.white)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildKanbanCard(
                              id: 'CMP-2026-000042',
                              title: 'Electrical Street Light Failure',
                              address: 'Ward 14, Main Road',
                              slaText: '18h 42m Remaining',
                              slaColor: Colors.green,
                            ),
                            _buildKanbanCard(
                              id: 'CMP-2026-000089',
                              title: 'Water Main Pipe Burst',
                              address: 'Bazaar Street, Usilampatti',
                              slaText: '2h 10m Warning Threshold!',
                              slaColor: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard({
    required String id,
    required String title,
    required String address,
    required String slaText,
    required Color slaColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Icon(Icons.drag_indicator_rounded, color: AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(address, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: slaColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 14, color: slaColor),
                const SizedBox(width: 4),
                Text(slaText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: slaColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
