import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';
import 'digital_signature_modal.dart';

class UniversalApprovalsInboxScreen extends StatefulWidget {
  const UniversalApprovalsInboxScreen({super.key});

  @override
  State<UniversalApprovalsInboxScreen> createState() => _UniversalApprovalsInboxScreenState();
}

class _UniversalApprovalsInboxScreenState extends State<UniversalApprovalsInboxScreen> {
  final List<Map<String, dynamic>> _approvals = [
    {
      'id': 'WO-2026-000012',
      'type': 'Work Order Sanction',
      'title': 'Road Resurfacing — Main Bazaar Ward 14',
      'initiator': 'Junior Engineer (Civil)',
      'amount': '₹ 7,50,000',
      'step': 'Step 2 of 3: AEE Review',
    },
    {
      'type': 'Building Permit NOC',
      'id': 'BP-2026-00045',
      'title': 'Commercial Complex Structural NOC',
      'initiator': 'Town Planning Inspector',
      'amount': 'N/A',
      'step': 'Step 1 of 2: Engineer Signoff',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Universal Executive Approvals Inbox', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Single unified inbox for executive officers to review and digitally sign pending requests.'),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _approvals.length,
            itemBuilder: (context, index) {
              final item = _approvals[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: Icon(Icons.approval_rounded, color: AppTheme.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(item['id'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 8),
                                Chip(label: Text(item['type'])),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('Initiated by: ${item['initiator']} • Value: ${item['amount']} • ${item['step']}'),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => DigitalSignatureModal(instanceId: item['id']),
                          );
                        },
                        icon: const Icon(Icons.draw_rounded),
                        label: const Text('Review & Sign'),
                      ),
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
