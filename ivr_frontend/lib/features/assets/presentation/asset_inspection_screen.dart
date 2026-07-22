import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class AssetInspectionScreen extends StatefulWidget {
  final String assetId;
  const AssetInspectionScreen({super.key, this.assetId = 'SL-MDU-Z3-042'});

  @override
  State<AssetInspectionScreen> createState() => _AssetInspectionScreenState();
}

class _AssetInspectionScreenState extends State<AssetInspectionScreen> {
  String _healthStatus = 'PASS';
  final _notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Field Inspection Audit — ${widget.assetId}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Record physical inspection checks, photo proof, and geotag accuracy.'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inspection Checklist Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'PASS', label: Text('Pass / Operational'), icon: Icon(Icons.verified_rounded)),
                      ButtonSegment(value: 'ATTENTION', label: Text('Requires Maintenance'), icon: Icon(Icons.warning_amber_rounded)),
                      ButtonSegment(value: 'FAIL', label: Text('Critical Breakdown'), icon: Icon(Icons.error_outline_rounded)),
                    ],
                    selected: {_healthStatus},
                    onSelectionChanged: (v) => setState(() => _healthStatus = v.first),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Inspector Audit Remarks & Findings'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt_rounded), label: const Text('Capture Geo-tagged Photo')),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inspection Audit Submitted Successfully!')));
                        },
                        icon: Icon(Icons.save_rounded, color: AppTheme.primary),
                        label: const Text('Submit Inspection Audit'),
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
