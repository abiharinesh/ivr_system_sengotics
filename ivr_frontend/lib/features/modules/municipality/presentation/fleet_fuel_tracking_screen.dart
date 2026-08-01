import 'package:flutter/material.dart';

class FleetFuelTrackingScreen extends StatelessWidget {
  const FleetFuelTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Municipal Vehicle Fleet & Fuel Telematics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('GPS vehicle location, diesel consumption log, and maintenance alerts.'),
        ],
      ),
    );
  }
}
