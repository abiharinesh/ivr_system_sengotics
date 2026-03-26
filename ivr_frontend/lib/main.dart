import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'core/env_maps_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web: plugins can post to flutter/lifecycle before the framework registers a listener.
  if (kIsWeb) {
    ui.channelBuffers.resize('flutter/lifecycle', 8);
  }
  await dotenv.load(fileName: '.env');
  await ensureMapsScriptLoaded(dotenv.env['GOOGLE_MAPS_API_KEY']);
  runApp(const App());
}
