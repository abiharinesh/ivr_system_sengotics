import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

/// Capture a camera image and a GPS snapshot at submission time (field workflows).
class FieldCapture {
  static Future<({Uint8List bytes, String filename, Position position, DateTime capturedAt})?>
  captureGeotaggedPhoto({ImageSource source = ImageSource.camera}) async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw StateError('Location permission denied');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (xfile == null) return null;

    final bytes = await xfile.readAsBytes();
    final name = xfile.name.isNotEmpty ? xfile.name : 'capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final capturedAt = DateTime.now().toUtc();

    return (
      bytes: bytes,
      filename: name,
      position: position,
      capturedAt: capturedAt,
    );
  }
}
