import 'package:flutter/material.dart';

class DrainageFloodScreen extends StatefulWidget {
  const DrainageFloodScreen({super.key});

  @override
  State<DrainageFloodScreen> createState() => _DrainageFloodScreenState();
}

class _DrainageFloodScreenState extends State<DrainageFloodScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Drainage & Flood Control Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Storm drain desilting schedules, low-lying flood hazard zone map, and monsoon emergency pump readiness.'),
        ],
      ),
    );
  }
}
