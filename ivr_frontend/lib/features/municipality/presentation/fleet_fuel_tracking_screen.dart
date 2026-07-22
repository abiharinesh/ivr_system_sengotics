import 'package:flutter/material.dart';

class FleetFuelTrackingScreen extends StatelessWidget {
  const FleetFuelTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Vehicle Fleet & Fuel Tracking Screen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Real-time GPS vehicle tracking map (garbage trucks, water tankers), fuel logs, and service due cards.'),
        ],
      ),
    );
  }
}
