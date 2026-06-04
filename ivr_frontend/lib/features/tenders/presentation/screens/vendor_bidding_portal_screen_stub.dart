import 'package:flutter/material.dart';

class VendorBiddingPortalScreen extends StatelessWidget {
  const VendorBiddingPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vendor Bidding Portal')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.web_rounded, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Vendor Bidding Portal is optimized for the web platform.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              SizedBox(height: 8),
              Text(
                'Please launch this operations console in a web browser to preview the live portal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
