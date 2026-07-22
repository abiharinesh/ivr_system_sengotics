import 'package:flutter/material.dart';

class CemeteryManagementScreen extends StatelessWidget {
  const CemeteryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Cemetery & Crematorium Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Burial slot & crematorium booking calendar, fuel/wood inventory gauge, and cremation certificates.'),
        ],
      ),
    );
  }
}
