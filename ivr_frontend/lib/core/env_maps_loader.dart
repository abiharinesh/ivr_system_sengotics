import 'env_maps_loader_stub.dart'
    if (dart.library.html) 'env_maps_loader_web.dart' as loader;

Future<void> ensureMapsScriptLoaded(String? apiKey) => loader.ensureMapsScriptLoaded(apiKey);
