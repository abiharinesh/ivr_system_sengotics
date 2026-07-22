import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class InspectorRouteDashboardScreen extends StatefulWidget {
  const InspectorRouteDashboardScreen({super.key});

  @override
  State<InspectorRouteDashboardScreen> createState() => _InspectorRouteDashboardScreenState();
}

class _InspectorRouteDashboardScreenState extends State<InspectorRouteDashboardScreen> {
  bool _isOnline = false;

  final List<Map<String, String>> _tasks = [
    {
      'site': 'SL-MDU-Z3-042 (Smart LED Pole)',
      'address': 'Ward 14, Main Road, Madurai',
      'priority': 'Urgent Fault',
      'dist': '1.2 km away',
    },
    {
      'site': 'WP-THM-012 (Water Pump Station)',
      'address': 'Thirumangalam Village Union',
      'priority': 'Routine Audit',
      'dist': '4.5 km away',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isOnline ? Colors.green : Colors.orange),
            ),
            child: Row(
              children: [
                Icon(_isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded, color: _isOnline ? Colors.green : Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isOnline ? 'Online Mode (Server Connected)' : 'Offline Mode Active (SQLite Local Cache Active • 3 Pending Sync Items)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: _isOnline ? Colors.green.shade900 : Colors.orange.shade900),
                  ),
                ),
                Switch(value: _isOnline, onChanged: (v) => setState(() => _isOnline = v)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Today\'s Field Inspection Route & Tasks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 28),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task['site']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text('${task['address']} • ${task['dist']}'),
                          ],
                        ),
                      ),
                      Chip(label: Text(task['priority']!)),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start Inspection')),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
