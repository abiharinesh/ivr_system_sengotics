import 'package:connectivity_plus/connectivity_plus.dart';

/// Best-effort: no connectivity interfaces usually means offline.
Future<bool> deviceAppearsOnline() async {
  final r = await Connectivity().checkConnectivity();
  return !r.contains(ConnectivityResult.none);
}
