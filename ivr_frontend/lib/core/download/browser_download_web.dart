import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web implementation: build an in-memory Blob and trigger a hidden anchor
/// click so the browser saves the file with [filename].
Future<void> saveBytes({
  required Uint8List bytes,
  required String filename,
  String? contentType,
}) async {
  final type = (contentType == null || contentType.isEmpty)
      ? 'application/octet-stream'
      : contentType;

  final blobParts = <JSAny>[bytes.toJS].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: type));
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  // Defer revocation so the browser has time to commit the download.
  scheduleMicrotask(() => web.URL.revokeObjectURL(url));
}

Future<void> printHtml(String htmlContent) async {
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
  
  // Set styles to keep it hidden off-screen and not alter the page layout
  iframe.style.position = 'fixed';
  iframe.style.width = '0';
  iframe.style.height = '0';
  iframe.style.border = 'none';
  iframe.style.visibility = 'hidden';
  
  web.document.body?.append(iframe);
  
  final iframeDoc = iframe.contentWindow?.document;
  if (iframeDoc != null) {
    iframeDoc.open();
    iframeDoc.write(htmlContent.toJS);
    iframeDoc.close();
    
    // Allow a small delay for the DOM and styling to parse/render inside the iframe
    await Future.delayed(const Duration(milliseconds: 150));
    
    iframe.contentWindow?.focus();
    iframe.contentWindow?.print();
  }
  
  // Clean up the iframe from the DOM after the print dialog is spawned
  Future.delayed(const Duration(seconds: 10), () {
    iframe.remove();
  });
}

