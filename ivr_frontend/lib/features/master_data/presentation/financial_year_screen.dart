import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class FinancialYearScreen extends StatefulWidget {
  const FinancialYearScreen({super.key});

  @override
  State<FinancialYearScreen> createState() => _FinancialYearScreenState();
}

class _FinancialYearScreenState extends State<FinancialYearScreen> {
  final List<Map<String, dynamic>> _fys = [
    {
      'code': 'FY 2025-26',
      'label': 'Financial Year 2025 - 2026',
      'start': '01-Apr-2025',
      'end': '31-Mar-2026',
      'isCurrent': true,
      'isLocked': false,
    },
    {
      'code': 'FY 2024-25',
      'label': 'Financial Year 2024 - 2025',
      'start': '01-Apr-2024',
      'end': '31-Mar-2025',
      'isCurrent': false,
      'isLocked': true,
    },
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
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Financial Year Manager', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Manage FY accounting periods and historical edit locks.'),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Create Financial Year'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: _fys.map((fy) {
              final isCurr = fy['isCurrent'] as bool;
              final isLock = fy['isLocked'] as bool;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isCurr ? AppTheme.primary : AppTheme.stroke, width: isCurr ? 2 : 1),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fy['code'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Chip(
                            label: Text(isCurr ? 'Current FY' : (isLock ? 'Locked' : 'Open')),
                            backgroundColor: isCurr ? Colors.green.shade100 : Colors.grey.shade200,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(fy['label']),
                      const SizedBox(height: 8),
                      Text('Period: ${fy['start']} to ${fy['end']}', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Lock Financial Modification'),
                          Switch(
                            value: isLock,
                            onChanged: (val) {
                              setState(() => fy['isLocked'] = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
