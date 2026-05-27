import 'package:flutter/material.dart';

/// Controller used to extract edited HTML from the [EditableHtmlSurface].
/// On non-web platforms this falls back to a raw [TextEditingController].
class EditableHtmlController {
  TextEditingController? _textController;

  /// Returns the current edited HTML string, or null if unavailable.
  String? getEditedHtml() => _textController?.text;
}

/// Non-web fallback: shows raw HTML in a scrollable text editor.
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
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.html);
    widget.controller._textController = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: TextField(
        controller: _ctrl,
        maxLines: null,
        expands: true,
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }
}
