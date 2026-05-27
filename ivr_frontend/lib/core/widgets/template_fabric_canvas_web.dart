// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'template_fabric_canvas_stub.dart' show FabricDesignExport;

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
  /// When null, parent must place this widget inside [Expanded].
  final double? height;

  @override
  State<TemplateFabricCanvas> createState() => TemplateFabricCanvasState();
}

class TemplateFabricCanvasState extends State<TemplateFabricCanvas> {
  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.MessageEvent>? _sub;
  Completer<FabricDesignExport>? _exportCompleter;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'template-fabric-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = 'template_canvas_editor.html?embed=1'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
      _iframe = iframe;
      return iframe;
    });
    _sub = html.window.onMessage.listen(_onMessage);
  }

  @override
  void didUpdateWidget(covariant TemplateFabricCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready &&
        (oldWidget.fabricScene != widget.fabricScene ||
            oldWidget.previewHtml != widget.previewHtml)) {
      loadEditor(
        fabricScene: widget.fabricScene,
        previewHtml: widget.previewHtml,
      );
    }
  }

  void _post(Map<String, dynamic> msg) {
    _iframe?.contentWindow?.postMessage(
      {'target': 'template_canvas_editor', ...msg},
      '*',
    );
  }

  void _onMessage(html.MessageEvent event) {
    final raw = event.data;
    if (raw == null) return;
    final Map<String, dynamic> map;
    if (raw is String) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    } else {
      return;
    }
    if (map['source'] != 'template_canvas_editor') return;

    switch (map['type']) {
      case 'ready':
        _ready = true;
        _post({'type': 'configure', 'embedded': true});
        loadEditor(
          fabricScene: widget.fabricScene,
          previewHtml: widget.previewHtml,
        );
        break;
      case 'dirty':
        widget.onDirty?.call();
        break;
      case 'export':
        _exportCompleter?.complete(
          FabricDesignExport(
            fabricScene: map['fabric_scene'] is Map
                ? Map<String, dynamic>.from(map['fabric_scene'] as Map)
                : null,
            overlaySvg: map['overlay_svg']?.toString(),
          ),
        );
        break;
    }
  }

  void loadScene(Map<String, dynamic>? scene) {
    loadEditor(fabricScene: scene, previewHtml: widget.previewHtml);
  }

  void loadEditor({
    Map<String, dynamic>? fabricScene,
    String? previewHtml,
  }) {
    if (!_ready) return;
    _post({
      'type': 'load',
      'fabric_scene': fabricScene,
      'preview_html': previewHtml ?? '',
    });
  }

  Future<FabricDesignExport?> exportDesign() async {
    if (_iframe == null || !_ready) return null;
    _exportCompleter = Completer<FabricDesignExport>();
    _post({'type': 'export'});
    try {
      return await _exportCompleter!.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iframe = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: HtmlElementView(viewType: _viewType),
    );
    if (widget.height != null) {
      return SizedBox(height: widget.height, child: iframe);
    }
    return iframe;
  }
}
