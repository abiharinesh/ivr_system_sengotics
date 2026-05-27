// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class HtmlPreviewSurface extends StatefulWidget {
  const HtmlPreviewSurface({super.key, required this.html});

  final String html;

  @override
  State<HtmlPreviewSurface> createState() => _HtmlPreviewSurfaceState();
}

class _HtmlPreviewSurfaceState extends State<HtmlPreviewSurface> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'html-preview-${DateTime.now().microsecondsSinceEpoch}';
    _register(widget.html);
  }

  void _register(String htmlContent) {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..srcdoc = htmlContent
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.html.trim().isEmpty) {
      return const Center(child: Text('No preview yet. Tap Preview.'));
    }
    return HtmlElementView(viewType: _viewType);
  }
}
