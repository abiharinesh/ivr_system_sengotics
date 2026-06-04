// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import '../../../config/api_config.dart';

class VendorBiddingPortalScreen extends StatefulWidget {
  const VendorBiddingPortalScreen({super.key});

  @override
  State<VendorBiddingPortalScreen> createState() => _VendorBiddingPortalScreenState();
}

class _VendorBiddingPortalScreenState extends State<VendorBiddingPortalScreen> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'vendor-bidding-portal-${DateTime.now().microsecondsSinceEpoch}';
    
    final portalUrl = '${ApiConfig.baseUrl}/docs/vendor-portal/vendor-dashboard.html';
    
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = portalUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HtmlElementView(viewType: _viewType),
    );
  }
}
