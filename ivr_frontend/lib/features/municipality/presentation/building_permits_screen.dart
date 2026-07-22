import 'package:flutter/material.dart';

class BuildingPermitsScreen extends StatelessWidget {
  const BuildingPermitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Building Permit & Plan Approval Screen', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Process citizen building plan applications, blueprint PDF reviews, and multi-dept NOC clearances.'),
        ],
      ),
    );
  }
}
