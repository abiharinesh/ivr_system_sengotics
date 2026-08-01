import 'package:flutter/material.dart';

class WorkingCalendarScreen extends StatefulWidget {
  const WorkingCalendarScreen({super.key});

  @override
  State<WorkingCalendarScreen> createState() => _WorkingCalendarScreenState();
}

class _WorkingCalendarScreenState extends State<WorkingCalendarScreen> {
  final List<Map<String, String>> _holidays = [
    {'date': '26-Jan-2026', 'nameEn': 'Republic Day', 'nameTa': 'குடியரசு தினம்', 'type': 'National Holiday'},
    {'date': '15-Jan-2026', 'nameEn': 'Pongal Festival', 'nameTa': 'பொங்கல் பண்டிகை', 'type': 'State Holiday'},
    {'date': '14-Apr-2026', 'nameEn': 'Tamil New Year', 'nameTa': 'தமிழ்ப் புத்தாண்டு', 'type': 'State Holiday'},
  ];

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
              Text('Working Calendar & Holidays (WorkingCalendar)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ElevatedButton(onPressed: null, child: Text('Add Holiday')),
            ],
          ),
          const SizedBox(height: 16),
          // Working hours card
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Government Working Hours (SLA Engine Context)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: ListTile(title: Text('Start Time'), subtitle: Text('09:30 AM'))),
                      Expanded(child: ListTile(title: Text('End Time'), subtitle: Text('05:45 PM'))),
                      Expanded(child: ListTile(title: Text('Working Days'), subtitle: Text('Mon, Tue, Wed, Thu, Fri, Sat'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Public Holiday List', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  DataTable(
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('English Name')),
                      DataColumn(label: Text('Tamil Name')),
                      DataColumn(label: Text('Category Type')),
                    ],
                    rows: _holidays.map((h) {
                      return DataRow(
                        cells: [
                          DataCell(Text(h['date']!, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(h['nameEn']!)),
                          DataCell(Text(h['nameTa']!)),
                          DataCell(Chip(label: Text(h['type']!))),
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
