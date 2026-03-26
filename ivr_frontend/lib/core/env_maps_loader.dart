import 'package:flutter/foundation.dart';

import 'env_maps_loader_stub.dart'
    if (dart.library.html) 'env_maps_loader_web.dart' as loader;

bool _mapsJsReady = !kIsWeb;

bool get isMapsJsReady => _mapsJsReady;

Future<void> ensureMapsScriptLoaded(String? apiKey) async {
  _mapsJsReady = await loader.ensureMapsScriptLoaded(apiKey);
}
