// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

class PdfPreviewSurface extends StatefulWidget {
  final Uint8List bytes;
  const PdfPreviewSurface({super.key, required this.bytes});

  @override
  State<PdfPreviewSurface> createState() => _PdfPreviewSurfaceState();
}

class _PdfPreviewSurfaceState extends State<PdfPreviewSurface> {
  late final String _viewType;
  late final String _blobUrl;

  @override
  void initState() {
    super.initState();
    final blob = html.Blob([widget.bytes], 'application/pdf');
    _blobUrl = html.Url.createObjectUrlFromBlob(blob);
    _viewType = 'pdf-preview-${DateTime.now().microsecondsSinceEpoch}-${widget.bytes.length}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = _blobUrl
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  @override
  void dispose() {
    html.Url.revokeObjectUrl(_blobUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
