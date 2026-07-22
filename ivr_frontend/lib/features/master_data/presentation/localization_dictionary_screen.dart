import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class LocalizationDictionaryScreen extends StatefulWidget {
  const LocalizationDictionaryScreen({super.key});

  @override
  State<LocalizationDictionaryScreen> createState() => _LocalizationDictionaryScreenState();
}

class _LocalizationDictionaryScreenState extends State<LocalizationDictionaryScreen> {
  final List<Map<String, String>> _translations = [
    {'key': 'complaint.status.pending', 'en': 'Pending Resolution', 'ta': 'நிலுவையில் உள்ளது'},
    {'key': 'complaint.status.resolved', 'en': 'Resolved', 'ta': 'தீர்க்கப்பட்டது'},
    {'key': 'asset.type.pole', 'en': 'Electric Pole / Street Light', 'ta': 'மின் கம்பம் / தெருவிளக்கு'},
    {'key': 'button.submit', 'en': 'Submit Grievance', 'ta': 'மனு தாக்கல் செய்க'},
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  Text('Localization Dictionary Manager', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Manage English (EN) and Tamil (TA) translation keys in real-time.'),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('Export JSON')),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.upload), label: const Text('Import JSON')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search translation keys or text...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Translation Key')),
                      DataColumn(label: Text('English Text (EN)')),
                      DataColumn(label: Text('Tamil Text (TA / தமிழ்)')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _translations.map((t) {
                      return DataRow(
                        cells: [
                          DataCell(Text(t['key']!, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                          DataCell(Text(t['en']!)),
                          DataCell(Text(t['ta']!)),
                          DataCell(IconButton(icon: Icon(Icons.edit, color: AppTheme.primary), onPressed: () {})),
                        ],
                      );
                    }).toList(),
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
