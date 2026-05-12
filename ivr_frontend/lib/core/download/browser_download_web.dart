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
