import 'package:flutter/material.dart';

class VitalEventsScreen extends StatelessWidget {
  const VitalEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vital Events Civil Registration (Birth & Death)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('CRS portal integration, birth/death certificate approvals, and institutional hospital logs.'),
        ],
      ),
    );
  }
}
