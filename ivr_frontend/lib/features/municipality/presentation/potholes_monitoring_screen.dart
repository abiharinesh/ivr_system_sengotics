import 'package:flutter/material.dart';

class PotholesMonitoringScreen extends StatefulWidget {
  const PotholesMonitoringScreen({super.key});

  @override
  State<PotholesMonitoringScreen> createState() => _PotholesMonitoringScreenState();
}

class _PotholesMonitoringScreenState extends State<PotholesMonitoringScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Road Condition & Pothole Monitoring', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('GIS Road pothole map, severity ratings, work order linking, and before/after repair photo logs.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.add_road_rounded, color: Colors.orange, size: 32),
                    title: Text('Ward 14 Main Road — Severe Pothole #089', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Reported 2 days ago • Severity: Critical • Work Order WO-2026-000012 Linked'),
                    trailing: Chip(label: Text('In Patchwork')),
                  ),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 140,
                          color: Colors.grey.shade200,
                          child: const Center(child: Text('Before Patchwork Photo')),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 140,
                          color: Colors.green.shade50,
                          child: const Center(child: Text('After Resurfacing Photo')),
                        ),
                      ),
                    ],
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
