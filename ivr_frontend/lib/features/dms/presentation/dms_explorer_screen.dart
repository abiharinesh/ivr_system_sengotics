import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class DmsExplorerScreen extends StatefulWidget {
  const DmsExplorerScreen({super.key});

  @override
  State<DmsExplorerScreen> createState() => _DmsExplorerScreenState();
}

class _DmsExplorerScreenState extends State<DmsExplorerScreen> {
  final List<Map<String, String>> _docs = [
    {'name': 'Gazette_Notification_2026.pdf', 'size': '2.4 MB', 'tag': 'G.O. Reference', 'version': 'v1.0'},
    {'name': 'Sanctioned_Blueprint_Ward14.pdf', 'size': '14.8 MB', 'tag': 'Building Permit', 'version': 'v2.1'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Directory tree sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(right: BorderSide(color: AppTheme.stroke)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DMS Directory Tree', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                const ListTile(leading: Icon(Icons.folder_rounded, color: Colors.amber), title: Text('Engineering & Works')),
                const ListTile(leading: Icon(Icons.folder_rounded, color: Colors.amber), title: Text('Revenue & Land Maps')),
                const ListTile(leading: Icon(Icons.folder_rounded, color: Colors.amber), title: Text('Grievance Attachments')),
              ],
            ),
          ),
          // Document List Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Document Management System (DMS Explorer)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('AWS S3 Abstraction • Document Versioning • e-Sign Certificate Cards'),
                        ],
                      ),
                      ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload_file_rounded), label: const Text('Upload Document')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Document Title')),
                          DataColumn(label: Text('File Size')),
                          DataColumn(label: Text('Tag Module')),
                          DataColumn(label: Text('Version')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _docs.map((d) {
                          return DataRow(
                            cells: [
                              DataCell(Text(d['name']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text(d['size']!)),
                              DataCell(Chip(label: Text(d['tag']!))),
                              DataCell(Chip(label: Text(d['version']!))),
                              DataCell(IconButton(icon: Icon(Icons.download_rounded, color: AppTheme.primary), onPressed: () {})),
                            ],
                          );
                        }).toList(),
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
}
