import 'package:flutter/material.dart';

class CemeteryManagementScreen extends StatelessWidget {
  const CemeteryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Burial Ground & Cemetery Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Slot bookings, crematorium status, and digital burial register.'),
        ],
      ),
    );
  }
}
