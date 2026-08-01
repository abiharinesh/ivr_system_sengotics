import 'package:flutter/material.dart';

class EncroachmentRemovalScreen extends StatelessWidget {
  const EncroachmentRemovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Public Land Encroachment Enforcement', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Eviction notices, legal stay orders, and demolition task force deployment.'),
        ],
      ),
    );
  }
}
