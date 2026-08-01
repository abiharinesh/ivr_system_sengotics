import 'package:flutter/material.dart';

class ParksOpenSpacesScreen extends StatelessWidget {
  const ParksOpenSpacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Parks, Gardens & Open Space Maintenance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Playground equipment inspections, horticulture contracts, and public entry fees.'),
        ],
      ),
    );
  }
}
