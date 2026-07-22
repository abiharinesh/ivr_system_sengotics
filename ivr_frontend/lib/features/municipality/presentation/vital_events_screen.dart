import 'package:flutter/material.dart';

class VitalEventsScreen extends StatelessWidget {
  const VitalEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Birth & Death Registration Registry', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Searchable vital events registry, hospital electronic feeds, and QR code certificate verification.'),
        ],
      ),
    );
  }
}
