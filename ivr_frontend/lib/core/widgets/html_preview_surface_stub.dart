import 'package:flutter/material.dart';

class HtmlPreviewSurface extends StatelessWidget {
  const HtmlPreviewSurface({super.key, required this.html});

  final String html;

  @override
  Widget build(BuildContext context) {
    if (html.trim().isEmpty) {
      return const Center(child: Text('No preview yet. Tap Preview.'));
    }
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: SelectableText(
          'HTML preview is available on Flutter web.\n\n${html.length > 2000 ? '${html.substring(0, 2000)}…' : html}',
          style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
