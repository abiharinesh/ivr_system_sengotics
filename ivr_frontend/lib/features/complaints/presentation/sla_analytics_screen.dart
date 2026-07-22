import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class SlaAnalyticsScreen extends StatefulWidget {
  const SlaAnalyticsScreen({super.key});

  @override
  State<SlaAnalyticsScreen> createState() => _SlaAnalyticsScreenState();
}

class _SlaAnalyticsScreenState extends State<SlaAnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SLA Compliance & Resolution Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Executive tracking of municipal SLA compliance rates and department resolution metrics.'),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildKpi('Overall SLA Compliance Rate', '94.2%', Icons.check_circle_rounded, Colors.green),
              const SizedBox(width: 16),
              _buildKpi('Total Resolved Grievance', '1,420 Resolved', Icons.task_alt_rounded, Colors.blue),
              const SizedBox(width: 16),
              _buildKpi('Active SLA Breaches', '8 Breached', Icons.error_outline_rounded, Colors.red),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Container(
              height: 350,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 64, color: AppTheme.primary),
                    const SizedBox(height: 12),
                    const Text('Department-Wise SLA Compliance Bar Chart', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Text('Engineering (96%) vs Public Health (92%) vs Sanitation (91%)'),
                  ],
                ),
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
            Icon(icon, color: color, size: 32),
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
