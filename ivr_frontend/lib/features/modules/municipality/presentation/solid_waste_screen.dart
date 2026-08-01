import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

class SolidWasteScreen extends StatefulWidget {
  const SolidWasteScreen({super.key});

  @override
  State<SolidWasteScreen> createState() => _SolidWasteScreenState();
}

class _SolidWasteScreenState extends State<SolidWasteScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Solid Waste Management & Sanitation Logs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Track public dumpster fill-levels, door-to-door waste collection routes, and sanitary worker logs.'),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildCard('Dumpsters Full (>80%)', '14 Dumpsters', Icons.delete_sweep_rounded, Colors.red),
              const SizedBox(width: 16),
              _buildCard('Collection Route Progress', '82% Completed', Icons.route_rounded, Colors.green),
              const SizedBox(width: 16),
              _buildCard('Sanitation Workers Active', '142 Workers', Icons.badge_rounded, Colors.blue),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Container(
              height: 350,
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map_rounded, size: 64, color: Colors.blue),
                    SizedBox(height: 12),
                    Text('Public Dumpster GIS Map (Green = Low, Yellow = Med, Red = Full)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.stroke)),
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
