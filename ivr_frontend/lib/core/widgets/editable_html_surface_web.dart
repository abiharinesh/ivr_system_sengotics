// ignore_for_file: deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

/// Controller used to extract edited HTML from the [EditableHtmlSurface].
/// On web this reads from the iframe's contentDocument.
class EditableHtmlController {
  html.IFrameElement? _iframe;

  /// Returns the current edited HTML string, or null if the iframe is not ready.
  String? getEditedHtml() {
    try {
      final iframe = _iframe;
      if (iframe == null) return null;
      final jsIframe = js.JsObject.fromBrowserObject(iframe);
      final doc = jsIframe['contentDocument'] as html.HtmlDocument?;
      if (doc == null) return null;
      // Turn off designMode before reading so the output is clean
      doc.execCommand('styleWithCSS', false, 'false');
      final raw = doc.documentElement?.outerHtml ?? '';
      // Strip the injected designMode bootstrap script
      final cleaned = raw.replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?document\.designMode[\s\S]*?</script>',
            caseSensitive: false),
        '',
      );
      return '<!DOCTYPE html>\n$cleaned';
    } catch (_) {
      return null;
    }
  }
}

/// Web implementation: renders HTML in an iframe with `designMode = 'on'`
/// so the user can edit the document content in-place (WYSIWYG).
class EditableHtmlSurface extends StatefulWidget {
  final String html;
  final EditableHtmlController controller;

  const EditableHtmlSurface({
    super.key,
    required this.html,
    required this.controller,
  });

  @override
  State<EditableHtmlSurface> createState() => _EditableHtmlSurfaceState();
}

class _EditableHtmlSurfaceState extends State<EditableHtmlSurface> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'editable-html-${DateTime.now().microsecondsSinceEpoch}';
    _register();
  }

  void _register() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..srcdoc = _makeEditable(widget.html)
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      widget.controller._iframe = iframe;
      return iframe;
    });
  }

  /// Injects a small bootstrap script that enables designMode after the
  /// document loads, making the iframe content editable like a rich-text
  /// editor. Also adds a subtle editing border.
  String _makeEditable(String htmlContent) {
    const editScript = '''
<script>
(function(){
  document.designMode = 'on';
  document.body.style.outline = 'none';
  document.body.style.minHeight = '100%';
  document.body.style.padding = '8px';
  document.body.style.boxSizing = 'border-box';
})();
</script>''';
    if (htmlContent.contains('</body>')) {
      return htmlContent.replaceFirst('</body>', '$editScript\n</body>');
    }
    return '$htmlContent$editScript';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.html.trim().isEmpty) {
      return const Center(child: Text('No content to edit.'));
    }
    return HtmlElementView(viewType: _viewType);
  }
}
