import 'dart:typed_data';

import 'browser_download_stub.dart'
    if (dart.library.html) 'browser_download_web.dart' as impl;

/// Prompt the browser (web) or the platform share/save sheet (mobile/desktop)
/// to save [bytes] under [filename]. On web this triggers a blob download via
/// a hidden anchor; on mobile it writes to a temp file and invokes share_plus.
Future<void> saveBytes({
  required Uint8List bytes,
  required String filename,
  String? contentType,
}) {
  return impl.saveBytes(
    bytes: bytes,
    filename: filename,
    contentType: contentType,
  );
}

/// Prompt system printing dialog with the given [htmlContent] string.
Future<void> printHtml(String htmlContent) {
  return impl.printHtml(htmlContent);
}
