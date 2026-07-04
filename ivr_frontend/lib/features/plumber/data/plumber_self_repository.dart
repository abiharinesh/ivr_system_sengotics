import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';

class PlumberSelfRepository {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> getMe() async {
    final data = await _api.get('/api/plumber/me');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<dynamic>> listComplaints({String? status}) async {
    final data = await _api.get(
      '/api/plumber/complaints',
      queryParams: status != null && status.isNotEmpty ? {'status': status} : null,
    );
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> getComplaint(int id) async {
    final data = await _api.get('/api/plumber/complaints/$id');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> accept(int id) async {
    final data = await _api.post('/api/plumber/complaints/$id/accept');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> decline(int id, {String? reason}) async {
    final data = await _api.post(
      '/api/plumber/complaints/$id/decline',
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
      '/api/plumber/complaints/$complaintId/resolve',
      form,
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
