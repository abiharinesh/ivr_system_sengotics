import '../../../core/api/api_client.dart';

class ReportsRepository {
  final ApiClient _api = ApiClient.instance;

  Future<Map<String, dynamic>> fetchPreview({
    required String service,
    required Map<String, dynamic> filters,
  }) async {
    final params = <String, dynamic>{
      'service': service,
      ...filters,
    };
    final res = await _api.get('/api/admin/reports/preview', queryParams: params);
    return Map<String, dynamic>.from(res as Map);
  }

  Future<DownloadedFile> downloadReport({
    required String service,
    required String format,
    required Map<String, dynamic> filters,
  }) async {
    final params = <String, dynamic>{
      'service': service,
      'format': format,
      ...filters,
    };
    final uri = Uri(path: '/api/admin/reports/download', queryParameters: params).toString();
    return _api.getDownload(uri);
  }
}
