import 'html_preview_surface_stub.dart'
    if (dart.library.html) 'html_preview_surface_web.dart' as impl;

class HtmlPreviewSurface extends impl.HtmlPreviewSurface {
  const HtmlPreviewSurface({
    super.key,
    required String html,
  }) : super(html: html);
}
