import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/api/api_client.dart';

class DocumentTemplateSettingsRepository {
  final ApiClient _api = ApiClient.instance;
  final bool isSuperAdmin;

  DocumentTemplateSettingsRepository({required this.isSuperAdmin});

  String get _base => isSuperAdmin
      ? ApiConfig.saDocumentTemplates
      : ApiConfig.paDocumentTemplates;

  Future<Map<String, dynamic>> fetchSettings() async {
    final data = await _api.get(_base);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> templates) async {
    final data = await _api.put(_base, data: {'templates': templates});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> resetPanchayatTemplate(String templateId) async {
    final data = await _api.delete('$_base/$templateId');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> saveDesign(
    String templateId, {
    Map<String, dynamic>? fabricScene,
    String? overlaySvg,
  }) async {
    final data = await _api.post('$_base/$templateId/design', data: {
      if (fabricScene != null) 'fabric_scene': fabricScene,
      if (overlaySvg != null) 'overlay_svg': overlaySvg,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<String> previewHtml(
    String templateId, {
    int? tenderId,
    int? vendorId,
    int? panchayatId,
  }) async {
    final body = <String, dynamic>{};
    if (tenderId != null) body['tender_id'] = tenderId;
    if (vendorId != null) body['vendor_id'] = vendorId;
    if (isSuperAdmin) {
      body['panchayat_id'] = panchayatId ?? 1;
    }
    return _api.postHtml('$_base/$templateId/preview', data: body);
  }
}
