import 'package:dio/dio.dart';

import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/api/api_client.dart';

class ElectricianRepository {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> getMe() async {
    final data = await _api.get(ApiConfig.electricianMe);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<dynamic>> listComplaints({String? status}) async {
    final data = await _api.get(
      ApiConfig.electricianComplaints,
      queryParams: status != null && status.isNotEmpty ? {'status': status} : null,
    );
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> getComplaint(int id) async {
    final data = await _api.get('${ApiConfig.electricianComplaints}/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> accept(int id) async {
    final data = await _api.post('${ApiConfig.electricianComplaints}/$id/accept');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> decline(int id, {String? reason}) async {
    final data = await _api.post(
      '${ApiConfig.electricianComplaints}/$id/decline',
      data: reason != null ? {'reason': reason} : <String, dynamic>{},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> submitResolution({
    required int complaintId,
    required List<int> imageBytes,
    required String fileName,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
    String? note,
    String? localJobId,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(imageBytes, filename: fileName),
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'capturedAt': capturedAt.toUtc().toIso8601String(),
      if (note != null && note.isNotEmpty) 'note': note,
      if (localJobId != null && localJobId.isNotEmpty) 'localJobId': localJobId,
    });
    final data = await _api.postMultipart(
      '${ApiConfig.electricianComplaints}/$complaintId/resolve',
      form,
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
