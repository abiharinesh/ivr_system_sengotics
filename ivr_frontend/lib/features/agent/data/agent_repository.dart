import 'package:dio/dio.dart';

import '../../../config/api_config.dart';
import '../../../core/api/api_client.dart';

class AgentRepository {
  final ApiClient _api = ApiClient.instance;

  Future<List<dynamic>> listPoles({String? search}) async {
    final data = await _api.get(
      ApiConfig.agentPoles,
      queryParams: search != null && search.isNotEmpty ? {'search': search} : null,
    );
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> getPole(int id) async {
    final data = await _api.get('${ApiConfig.agentPoles}/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> uploadPoleImage({
    required int poleId,
    required List<int> imageBytes,
    required String fileName,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'capturedAt': capturedAt.toUtc().toIso8601String(),
    });
    final data = await _api.postMultipart(
      '${ApiConfig.agentPoles}/$poleId/image',
      form,
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createPoleWithImage({
    required List<int> imageBytes,
    required String fileName,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
    String? poleNumber,
    String? keypadId,
    List<String>? landmarks,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      if (poleNumber != null && poleNumber.isNotEmpty) 'pole_number': poleNumber,
      if (keypadId != null && keypadId.isNotEmpty) 'keypad_id': keypadId,
      if (landmarks != null && landmarks.isNotEmpty) 'landmarks': landmarks.join(','),
    });
    final data = await _api.postMultipart(ApiConfig.agentPoles, form);
    return Map<String, dynamic>.from(data as Map);
  }

  /// JSON-only pole (no photo); use when capturing image separately.
  Future<Map<String, dynamic>> createPoleJson({
    String? poleNumber,
    String? keypadId,
    double? latitude,
    double? longitude,
    List<String>? landmarks,
  }) async {
    final data = await _api.post(ApiConfig.agentPoles, data: {
      if (poleNumber != null) 'pole_number': poleNumber,
      if (keypadId != null) 'keypad_id': keypadId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (landmarks != null) 'landmarks': landmarks,
    });
    return Map<String, dynamic>.from(data as Map);
  }
}
