import 'package:flutter/material.dart';

class ExecutiveDashboardScreen extends StatefulWidget {
  const ExecutiveDashboardScreen({super.key});

  @override
  State<ExecutiveDashboardScreen> createState() => _ExecutiveDashboardScreenState();
}

class _ExecutiveDashboardScreenState extends State<ExecutiveDashboardScreen> {
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
              Text('Role-Based Executive Widget Grid', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Chip(label: Text('Role View: Executive Leadership'), backgroundColor: Colors.purpleAccent),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildWidgetCard('Grievance Resolution SLA Gauge', '94% SLA Compliance', Icons.speed_rounded, Colors.green),
              _buildWidgetCard('Spatial GIS Hotspot Heatmap', '12 Active Clusters', Icons.map_rounded, Colors.orange),
              _buildWidgetCard('Asset Health Status', '88% Operational', Icons.lightbulb_rounded, Colors.blue),
              _buildWidgetCard('Budget Utilization Bar Chart', '₹ 4.2 Cr Utilization', Icons.monetization_on_rounded, Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetCard(String title, String val, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const Spacer(),
            Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
