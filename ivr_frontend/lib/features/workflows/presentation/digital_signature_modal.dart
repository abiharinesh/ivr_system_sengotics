import 'package:flutter/material.dart';

class DigitalSignatureModal extends StatefulWidget {
  final String instanceId;
  const DigitalSignatureModal({super.key, required this.instanceId});

  @override
  State<DigitalSignatureModal> createState() => _DigitalSignatureModalState();
}

class _DigitalSignatureModalState extends State<DigitalSignatureModal> {
  String _sigMode = 'PIN';
  final _remarksController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Execute Decision & Sign — ${widget.instanceId}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Decision Action:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Approve'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Reject'))),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarksController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Official Remarks / Rejection Rationale'),
            ),
            const SizedBox(height: 16),
            const Text('Digital Signature Authentication Mode:', style: TextStyle(fontWeight: FontWeight.bold)),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PIN', label: Text('PIN Passcode')),
                ButtonSegment(value: 'BIOMETRIC', label: Text('TouchID')),
                ButtonSegment(value: 'TOKEN', label: Text('e-Sign USB Token')),
              ],
              selected: {_sigMode},
              onSelectionChanged: (v) => setState(() => _sigMode = v.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Enter 6-Digit Signing PIN'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Approval executed with Digital Signature hash!')),
            );
          },
          child: const Text('Submit Signed Approval'),
        ),
      ],
    );
  }
}
