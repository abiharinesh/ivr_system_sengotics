import 'package:flutter/material.dart';

/// Mobile/desktop stub — full Fabric editor runs on Flutter web only.
class TemplateFabricCanvas extends StatefulWidget {
  const TemplateFabricCanvas({
    super.key,
    this.fabricScene,
    this.previewHtml,
    this.onDirty,
    this.height,
  });

  final Map<String, dynamic>? fabricScene;
  final String? previewHtml;
  final VoidCallback? onDirty;
  final double? height;

  @override
  State<TemplateFabricCanvas> createState() => TemplateFabricCanvasState();
}

class TemplateFabricCanvasState extends State<TemplateFabricCanvas> {
  Future<FabricDesignExport?> exportDesign() async => null;

  void loadScene(Map<String, dynamic>? scene) {}

  void loadEditor({
    Map<String, dynamic>? fabricScene,
    String? previewHtml,
  }) {}

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.web_asset, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'Full template canvas editor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Open this app in a web browser to use the Fabric design canvas '
              '(text, shapes, images, draw) with the document as background.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
    if (widget.height != null) {
      return SizedBox(height: widget.height, child: card);
    }
    return card;
  }
}

class FabricDesignExport {
  final Map<String, dynamic>? fabricScene;
  final String? overlaySvg;

  const FabricDesignExport({this.fabricScene, this.overlaySvg});
}
