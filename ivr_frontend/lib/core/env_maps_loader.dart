import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;

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

/// Helper to get the Map ID dynamically. Defaults to 'DEMO_MAP_ID' on web to prevent deprecation warning.
String? get googleMapsMapId {
  final envId = dotenv.env['GOOGLE_MAPS_MAP_ID']?.trim();
  if (kIsWeb) {
    return (envId != null && envId.isNotEmpty) ? envId : 'DEMO_MAP_ID';
  }
  return (envId != null && envId.isNotEmpty) ? envId : null;
}

/// Helper to get the correct MarkerType based on the map ID availability.
gmap.GoogleMapMarkerType get googleMapsMarkerType {
  return googleMapsMapId != null
      ? gmap.GoogleMapMarkerType.advancedMarker
      : gmap.GoogleMapMarkerType.marker;
}
