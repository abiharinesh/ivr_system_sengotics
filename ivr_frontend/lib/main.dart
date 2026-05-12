import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/env_maps_loader.dart';
import 'core/offline/field_outbox.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    // Path URLs: http://host/dashboard instead of /#/dashboard.
    // Production static hosts must rewrite unknown paths to index.html (SPA fallback)
    // or deep links and refresh on /dashboard will 404.
    usePathUrlStrategy();
    // Plugins can post to flutter/lifecycle before the framework registers a listener.
    ui.channelBuffers.resize('flutter/lifecycle', 8);
  }
  await Hive.initFlutter();
  await Hive.openBox(FieldOutbox.boxName);
  await dotenv.load(fileName: '.env');
  await ensureMapsScriptLoaded(dotenv.env['GOOGLE_MAPS_API_KEY']);
  runApp(const App());
}
