import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';

class FormTemplateBuilderScreen extends StatefulWidget {
  const FormTemplateBuilderScreen({super.key});

  @override
  State<FormTemplateBuilderScreen> createState() => _FormTemplateBuilderScreenState();
}

class _FormTemplateBuilderScreenState extends State<FormTemplateBuilderScreen> {
  final List<String> _canvasFields = [
    'Applicant Aadhaar Number (Text Input, Mandatory)',
    'Property Survey Map (File Uploader)',
    'Building Height in Meters (Number Field)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Tool Palette
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(right: BorderSide(color: AppTheme.stroke)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Available Component Types', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _buildToolPaletteItem('Text Input Field', Icons.text_fields),
                _buildToolPaletteItem('Number Field', Icons.numbers),
                _buildToolPaletteItem('Dropdown Select', Icons.arrow_drop_down_circle),
                _buildToolPaletteItem('Geotagged Map Pin', Icons.pin_drop),
                _buildToolPaletteItem('Digital Signature Pad', Icons.draw),
                _buildToolPaletteItem('Multi-Photo Camera Capture', Icons.camera_alt),
              ],
            ),
          ),
          // Center Canvas
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Form Layout Schema Designer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ElevatedButton(onPressed: null, child: Text('Publish Schema JSON')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Container(
                      height: 500,
                      padding: const EdgeInsets.all(20),
                      child: ListView.builder(
                        itemCount: _canvasFields.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.stroke),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.drag_indicator),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_canvasFields[index], style: const TextStyle(fontWeight: FontWeight.bold))),
                                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () {}),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolPaletteItem(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
