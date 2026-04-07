import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../features/agent/data/agent_repository.dart';
import '../../features/electrician/data/electrician_repository.dart';

/// Persists field upload jobs when offline; clear after successful sync.
class FieldOutbox {
  FieldOutbox._();

  static const boxName = 'field_outbox';

  static Box<dynamic> get _box => Hive.box(boxName);

  static Future<String> _newFile(String prefix, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.bin';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> enqueuePoleImage({
    required int poleId,
    required List<int> imageBytes,
    required String fileName,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
  }) async {
    final id = 'pole_${poleId}_${DateTime.now().millisecondsSinceEpoch}';
    final path = await _newFile('pole_$poleId', imageBytes);
    await _box.put(id, {
      'kind': 'pole_image',
      'poleId': poleId,
      'filePath': path,
      'fileName': fileName,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
    });
  }

  static Future<void> enqueuePoleCreate({
    required List<int> imageBytes,
    required String fileName,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
    String? poleNumber,
    String? keypadId,
  }) async {
    final id = 'pole_create_${DateTime.now().millisecondsSinceEpoch}';
    final path = await _newFile('pole_new', imageBytes);
    await _box.put(id, {
      'kind': 'pole_create',
      'filePath': path,
      'fileName': fileName,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      if (poleNumber != null) 'poleNumber': poleNumber,
      if (keypadId != null) 'keypadId': keypadId,
    });
  }

  static Future<void> enqueueResolve({
    required int complaintId,
    required List<int> imageBytes,
    required String fileName,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
    String? note,
    String? localJobId,
  }) async {
    final id = localJobId ?? 'res_${complaintId}_${DateTime.now().millisecondsSinceEpoch}';
    final path = await _newFile('res_$complaintId', imageBytes);
    await _box.put(id, {
      'kind': 'complaint_resolve',
      'complaintId': complaintId,
      'filePath': path,
      'fileName': fileName,
      'latitude': latitude,
      'longitude': longitude,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      if (note != null && note.isNotEmpty) 'note': note,
      if (localJobId != null) 'localJobId': localJobId,
    });
  }

  static int get pendingCount => _box.length;

  static Future<void> syncAll({
    AgentRepository? agentRepo,
    ElectricianRepository? electricianRepo,
  }) async {
    final keys = _box.keys.cast<dynamic>().toList();
    for (final key in keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final m = Map<String, dynamic>.from(raw as Map);
      final kind = m['kind'] as String?;
      final filePath = m['filePath'] as String?;
      if (kind == null || filePath == null) continue;

      try {
        final file = File(filePath);
        if (!await file.exists()) {
          await _box.delete(key);
          continue;
        }
        final bytes = await file.readAsBytes();

        if (kind == 'pole_image' && agentRepo != null) {
          final poleId = m['poleId'] as int;
          await agentRepo.uploadPoleImage(
            poleId: poleId,
            imageBytes: bytes,
            fileName: m['fileName'] as String? ?? 'photo.jpg',
            latitude: (m['latitude'] as num).toDouble(),
            longitude: (m['longitude'] as num).toDouble(),
            capturedAt: DateTime.parse(m['capturedAt'] as String),
          );
        } else if (kind == 'pole_create' && agentRepo != null) {
          await agentRepo.createPoleWithImage(
            imageBytes: bytes,
            fileName: m['fileName'] as String? ?? 'pole.jpg',
            latitude: (m['latitude'] as num).toDouble(),
            longitude: (m['longitude'] as num).toDouble(),
            capturedAt: DateTime.parse(m['capturedAt'] as String),
            poleNumber: m['poleNumber'] as String?,
            keypadId: m['keypadId'] as String?,
          );
        } else if (kind == 'complaint_resolve' && electricianRepo != null) {
          await electricianRepo.submitResolution(
            complaintId: m['complaintId'] as int,
            imageBytes: bytes,
            fileName: m['fileName'] as String? ?? 'proof.jpg',
            latitude: (m['latitude'] as num).toDouble(),
            longitude: (m['longitude'] as num).toDouble(),
            capturedAt: DateTime.parse(m['capturedAt'] as String),
            note: m['note'] as String?,
            localJobId: m['localJobId'] as String?,
          );
        } else {
          continue;
        }

        await file.delete();
        await _box.delete(key);
      } catch (_) {
        /* keep in queue for retry */
      }
    }
  }
}
