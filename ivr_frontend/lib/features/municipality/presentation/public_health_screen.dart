import 'package:flutter/material.dart';

class PublicHealthScreen extends StatelessWidget {
  const PublicHealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Public Health & Vector Disease Control', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Dengue fogging schedules, trade license health inspections, and food safety audits.'),
        ],
      ),
    );
  }
}
