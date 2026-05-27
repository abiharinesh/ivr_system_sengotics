import 'dart:typed_data';

import 'pdf_preview_surface_stub.dart'
    if (dart.library.html) 'pdf_preview_surface_web.dart' as impl;

class PdfPreviewSurface extends impl.PdfPreviewSurface {
  const PdfPreviewSurface({
    super.key,
    required Uint8List bytes,
  }) : super(bytes: bytes);
}
