import 'template_fabric_canvas_stub.dart'
    if (dart.library.html) 'template_fabric_canvas_web.dart' as impl;

export 'template_fabric_canvas_stub.dart' show FabricDesignExport;

class TemplateFabricCanvas extends impl.TemplateFabricCanvas {
  const TemplateFabricCanvas({
    super.key,
    super.fabricScene,
    super.previewHtml,
    super.onDirty,
    super.height,
  });
}

typedef TemplateFabricCanvasState = impl.TemplateFabricCanvasState;
