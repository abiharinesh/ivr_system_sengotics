import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';

class BranchGisDrawerScreen extends StatefulWidget {
  final String branchId;
  const BranchGisDrawerScreen({super.key, this.branchId = 'USL-BLK-12'});

  @override
  State<BranchGisDrawerScreen> createState() => _BranchGisDrawerScreenState();
}

class _BranchGisDrawerScreenState extends State<BranchGisDrawerScreen> {
  final _latController = TextEditingController(text: '9.9824');
  final _lngController = TextEditingController(text: '77.7981');
  final _areaController = TextEditingController(text: '142.50');

  final List<String> _surveyNumbers = ['104/1A', '104/1B', '105/2', '108/4C'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // GIS Map Drawer Area
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  color: Colors.blueGrey.shade100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_rounded, size: 80, color: AppTheme.primary),
                        const SizedBox(height: 16),
                        const Text(
                          'Interactive Spatial Geofence Map Canvas',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('Click map vertices to draw / edit GeoJSON boundary polygon'),
                      ],
                    ),
                  ),
                ),
                // Floating Draw Toolbar
                Positioned(
                  top: 20,
                  left: 20,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.polyline_rounded, color: AppTheme.primary),
                            tooltip: 'Draw Boundary Polygon',
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_location_alt_rounded),
                            tooltip: 'Edit Vertices',
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.layers_rounded),
                            tooltip: 'Toggle Satellite / Topo View',
                            onPressed: () {},
                          ),
                          const VerticalDivider(),
                          ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.file_upload_outlined, size: 18),
                            label: const Text('Import GeoJSON'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Sidebar Attributes Inspector
          Container(
            width: 380,
            color: Colors.white,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spatial GIS Attributes — ${widget.branchId}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Define central coordinates, spatial area, and ward survey bounds.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(labelText: 'Center Latitude'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: const InputDecoration(labelText: 'Center Longitude'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _areaController,
                  decoration: const InputDecoration(
                    labelText: 'Total Area (Sq Km)',
                    suffixText: 'sq km',
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Containment Survey Numbers List',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._surveyNumbers.map(
                      (num) => Chip(
                        label: Text(num),
                        onDeleted: () {
                          setState(() => _surveyNumbers.remove(num));
                        },
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Add Survey No'),
                      onPressed: () {
                        setState(() => _surveyNumbers.add('110/3A'));
                      },
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('GIS Boundary Polygon Saved Successfully!')),
                      );
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Save Spatial Geofence'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
