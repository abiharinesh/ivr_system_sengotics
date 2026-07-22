import 'package:flutter/material.dart';

class PublicHealthScreen extends StatelessWidget {
  const PublicHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Public Health & Sanitation Drive', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Vector control mosquito fogging schedules, food hygiene score audits, outbreak alerts.'),
        ],
      ),
    );
  }
}
