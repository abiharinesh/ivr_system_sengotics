import 'package:flutter/foundation.dart';

import 'env_maps_loader_stub.dart'
    if (dart.library.html) 'env_maps_loader_web.dart' as loader;

bool _mapsJsReady = !kIsWeb;
bool _mapsWebSkippedForMissingKey = false;

bool get isMapsJsReady => _mapsJsReady;

/// On web only: true when `GOOGLE_MAPS_API_KEY` was empty / missing at startup.
bool get mapsWebMissingApiKey => kIsWeb && _mapsWebSkippedForMissingKey;

/// User-facing text when [isMapsJsReady] is false on web.
String get mapsWebUnavailableMessage {
  if (!kIsWeb) return '';
  if (mapsWebMissingApiKey) {
    return 'Set GOOGLE_MAPS_API_KEY in ivr_frontend/.env (a real key, not the placeholder).\n'
        'Enable “Maps JavaScript API” for that key and allow this origin under HTTP referrers '
        '(e.g. http://localhost:8080/*). Then fully restart the app (not hot reload).';
  }
  return 'Google Maps script failed to load. Check billing, API restrictions, and ad blockers, '
      'then refresh the page.';
}

Future<void> ensureMapsScriptLoaded(String? apiKey) async {
  if (!kIsWeb) {
    _mapsJsReady = true;
    _mapsWebSkippedForMissingKey = false;
    return;
  }
  final trimmed = apiKey?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    _mapsJsReady = false;
    _mapsWebSkippedForMissingKey = true;
    return;
  }
  _mapsWebSkippedForMissingKey = false;
  _mapsJsReady = await loader.ensureMapsScriptLoaded(apiKey);
}
