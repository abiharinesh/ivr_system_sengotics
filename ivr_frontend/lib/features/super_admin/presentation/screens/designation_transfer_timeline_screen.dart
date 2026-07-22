import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class DesignationTransferTimelineScreen extends StatefulWidget {
  final String empId;
  const DesignationTransferTimelineScreen({super.key, this.empId = 'EMP-00042'});

  @override
  State<DesignationTransferTimelineScreen> createState() => _DesignationTransferTimelineScreenState();
}

class _DesignationTransferTimelineScreenState extends State<DesignationTransferTimelineScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Posting & Designation History Timeline — ${widget.empId}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Official transfer records, Government Order (G.O.) citations, and past designations.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(child: Text(widget.empId.substring(4))),
                    title: const Text('K. Rajasekar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: const Text('TNCS Senior Executive Cadre'),
                  ),
                  const Divider(height: 32),
                  _buildTimelineItem('2024 - Present', 'Block Development Officer (BDO)', 'Usilampatti Panchayat Union', 'G.O. Ms. No. 142/RD&PR'),
                  _buildTimelineItem('2021 - 2024', 'Assistant Development Officer', 'Thirumangalam Panchayat Union', 'G.O. Ms. No. 89/RD&PR'),
                  _buildTimelineItem('2012 - 2021', 'Junior Assistant', 'Madurai Collectorate Headquarters', 'G.O. Ms. No. 12/RD&PR'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String date, String role, String loc, String go) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            child: const Icon(Icons.work_history, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('$loc • $date', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Ref: $go', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
