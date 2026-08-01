import 'package:flutter/material.dart';

class OfflineFieldInspectionScreen extends StatefulWidget {
  const OfflineFieldInspectionScreen({super.key});

  @override
  State<OfflineFieldInspectionScreen> createState() => _OfflineFieldInspectionScreenState();
}

class _OfflineFieldInspectionScreenState extends State<OfflineFieldInspectionScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Offline Mode: Submission will be queued in SQLite database.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Watermarked Photo Capture Widget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                    child: const Stack(
                      children: [
                        Center(child: Icon(Icons.camera_alt, color: Colors.white, size: 48)),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          child: Text(
                            'Watermark: LAT 9.9824 • LNG 77.7981 • 2026-07-22 15:30 • Inspector EMP-00042',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save Inspection to Offline Sync Queue'),
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
