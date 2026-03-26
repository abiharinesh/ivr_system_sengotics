import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Injects the Google Maps JS script with [apiKey] and returns true if loaded.
Future<bool> ensureMapsScriptLoaded(String? apiKey) async {
  if (apiKey == null || apiKey.isEmpty) return false;
  final key = apiKey.trim();
  final src =
      'https://maps.googleapis.com/maps/api/js?key=$key&loading=async&libraries=marker&v=weekly';

  final existingScript = web.document.querySelector(
    'script[src*="maps.googleapis.com/maps/api/js"]',
  );
  if (existingScript != null) {
    final existingSrc = (existingScript as web.HTMLScriptElement).src;
    if (existingSrc.contains('loading=async')) {
      return true;
    }
    // Remove stale direct-loader scripts to avoid warning spam.
    existingScript.remove();
  }

  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src = src
    ..async = true
    ..defer = true;

  final completer = Completer<bool>();

  late JSFunction onLoad;
  late JSFunction onError;

  onLoad = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete(true);
    }
    script.removeEventListener('load', onLoad);
    script.removeEventListener('error', onError);
  }).toJS;

  onError = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete(false);
    }
    script.removeEventListener('load', onLoad);
    script.removeEventListener('error', onError);
  }).toJS;

  script.addEventListener('load', onLoad);
  script.addEventListener('error', onError);
  web.document.head?.append(script);

  return completer.future;
}
