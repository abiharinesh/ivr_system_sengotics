import 'package:flutter/material.dart';

class ParksOpenSpacesScreen extends StatelessWidget {
  const ParksOpenSpacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Parks & Open Spaces Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Park equipment inventory, mowing/watering schedules, and footfall logs.'),
        ],
      ),
    );
  }
}
