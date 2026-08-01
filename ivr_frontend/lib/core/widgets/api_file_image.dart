import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:ivr_frontend/core/api/api_client.dart';

/// Loads `/uploads/...` files via the API client (works on Flutter web; avoids
/// cross-origin Image.network failures against the NestJS static host).
class ApiFileImage extends StatefulWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;

  const ApiFileImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
  });

  @override
  State<ApiFileImage> createState() => _ApiFileImageState();
}

class _ApiFileImageState extends State<ApiFileImage> {
  static final _cache = <String, Uint8List>{};
  Future<Uint8List>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ApiFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  void _load() {
    final path = widget.path;
    if (path == null || path.isEmpty) {
      _future = null;
      return;
    }
    final cached = _cache[path];
    if (cached != null) {
      _future = Future.value(cached);
      return;
    }
    _future = ApiClient.instance.getBytes(path).then((bytes) {
      _cache[path] = bytes;
      return bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (path == null || path.isEmpty) {
      return widget.placeholder ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
          );
    }

    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return widget.error ??
              Container(
                width: widget.width,
                height: widget.height,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_outlined),
              );
        }
        return Image.memory(
          snap.data!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
      },
    );
  }
}
