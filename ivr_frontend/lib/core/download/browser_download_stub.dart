import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile / desktop implementation: write to a temp file, then surface the
/// platform share/save sheet so the user picks a destination (Files, Drive,
/// Gmail, etc).
Future<void> saveBytes({
  required Uint8List bytes,
  required String filename,
  String? contentType,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, filename));
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: contentType, name: filename)],
    subject: filename,
  );
}

Future<void> printHtml(String htmlContent) async {
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'print_report.html'));
  await file.writeAsString(htmlContent, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/html', name: 'print_report.html')],
    subject: 'Print Report',
  );
}
