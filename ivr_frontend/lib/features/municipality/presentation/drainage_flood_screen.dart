import 'package:flutter/material.dart';

class DrainageFloodScreen extends StatefulWidget {
  const DrainageFloodScreen({super.key});

  @override
  State<DrainageFloodScreen> createState() => _DrainageFloodScreenState();
}

class _DrainageFloodScreenState extends State<DrainageFloodScreen> {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Storm Water Drainage & Monsoon Flood Monitoring', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Canal desilting progress, IoT water level sensors, and flood alert control room.'),
        ],
      ),
    );
  }
}
