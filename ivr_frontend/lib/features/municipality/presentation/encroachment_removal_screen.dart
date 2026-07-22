import 'package:flutter/material.dart';

class EncroachmentRemovalScreen extends StatelessWidget {
  const EncroachmentRemovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Encroachment Removal & Survey Monitor', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Encroachment GIS map, eviction notice generator (Form I & II), and demolition drive logs.'),
        ],
      ),
    );
  }
}
