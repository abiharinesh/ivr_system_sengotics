import 'dart:typed_data';

import 'package:flutter/material.dart';

class PdfPreviewSurface extends StatelessWidget {
  final Uint8List bytes;
  const PdfPreviewSurface({super.key, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Inline PDF preview is supported on web.\nUse Download to view this file on this platform.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
