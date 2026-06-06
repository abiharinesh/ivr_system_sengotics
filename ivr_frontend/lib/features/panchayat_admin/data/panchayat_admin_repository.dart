import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../config/api_config.dart';
import '../../../core/models/user_model.dart';
import '../../super_admin/data/models/complaint_model.dart';
import '../../../core/models/pole_model.dart';
import '../../../core/models/stats_model.dart';
import '../../../core/models/dashboard_insights_model.dart';

class PanchayatAdminRepository {
  final ApiClient _api = ApiClient.instance;

  // ── Profile ─────────────────────────────────────────────────────────────
  Future<UserModel> getMe() async {
    final data = await _api.get(ApiConfig.paMe);
    return UserModel.fromJson(data);
  }

  // ── Stats ───────────────────────────────────────────────────────────────
  StatsModel? getCachedStats() {
    final cached = _api.getCached(ApiConfig.paStats);
    if (cached == null) return null;
    return StatsModel.fromJson(cached);
  }

  Future<StatsModel> getStats({bool forceRefresh = false}) async {
    final data = await _api.get(ApiConfig.paStats, forceRefresh: forceRefresh);
    return StatsModel.fromJson(data);
  }

  DashboardInsights? getCachedDashboardInsights() {
    final cached = _api.getCached(ApiConfig.paDashboardInsights);
    if (cached == null) return null;
    return DashboardInsights.fromJson(Map<String, dynamic>.from(cached as Map));
  }

  Future<DashboardInsights> getDashboardInsights({bool forceRefresh = false}) async {
    final data = await _api.get(ApiConfig.paDashboardInsights, forceRefresh: forceRefresh);
    return DashboardInsights.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Poles ───────────────────────────────────────────────────────────────
  List<PoleModel>? getCachedPoles() {
    final cached = _api.getCached(ApiConfig.paPoles);
    if (cached == null) return null;
    return (cached as List).map((j) => PoleModel.fromJson(j)).toList();
  }

  Future<List<PoleModel>> listPoles({bool forceRefresh = false}) async {
    final data = await _api.get(ApiConfig.paPoles, forceRefresh: forceRefresh);
    return (data as List).map((j) => PoleModel.fromJson(j)).toList();
  }

  Future<PoleModel> createPole(Map<String, dynamic> body) async {
    final data = await _api.post(ApiConfig.paPoles, data: body);
    return PoleModel.fromJson(data);
  }

  Future<PoleModel> updatePole(int id, Map<String, dynamic> body) async {
    final data = await _api.put('${ApiConfig.paPoles}/$id', data: body);
    return PoleModel.fromJson(data);
  }

  Future<void> deletePole(int id) async {
    await _api.delete('${ApiConfig.paPoles}/$id');
  }

  // ── Complaints ──────────────────────────────────────────────────────────
  List<ComplaintModel>? getCachedComplaints({String? status}) {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final cached = _api.getCached(ApiConfig.paComplaints, queryParams: params.isEmpty ? null : params);
    if (cached == null) return null;
    return (cached as List).map((j) => ComplaintModel.fromJson(j)).toList();
  }

  Future<List<ComplaintModel>> listComplaints({String? status, bool forceRefresh = false}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final data = await _api.get(ApiConfig.paComplaints, queryParams: params.isEmpty ? null : params, forceRefresh: forceRefresh);
    return (data as List).map((j) => ComplaintModel.fromJson(j)).toList();
  }

  Future<ComplaintModel> updateComplaintStatus(int id, String status) async {
    final data = await _api.patch(
      '${ApiConfig.paComplaints}/$id/status',
      data: {'status': status},
    );
    return ComplaintModel.fromJson(data);
  }

  Future<ComplaintModel> resolveComplaint(int id, int poleId) async {
    final data = await _api.patch(
      '${ApiConfig.paComplaints}/$id/resolve',
      data: {'pole_id': poleId},
    );
    return ComplaintModel.fromJson(data);
  }

  Future<ComplaintModel> assignElectrician(int complaintId, int electricianUserId) async {
    final data = await _api.patch(
      '${ApiConfig.paComplaints}/$complaintId/assign-electrician',
      data: {'electrician_user_id': electricianUserId},
    );
    return ComplaintModel.fromJson(data);
  }

  Future<ComplaintModel> createComplaint({
    required int poleId,
    required String complaintType,
    required String description,
    String? urgencyLevel,
  }) async {
    final data = await _api.post(
      ApiConfig.paComplaints,
      data: {
        'pole_id': poleId,
        'complaint_type': complaintType,
        'description': description,
        if (urgencyLevel != null && urgencyLevel.isNotEmpty)
          'urgency_level': urgencyLevel,
      },
    );
    return ComplaintModel.fromJson(data);
  }

  Future<List<dynamic>> listElectricians() async {
    final data = await _api.get(ApiConfig.paElectricians);
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> createElectrician({
    required String email,
    required String password,
    String? phoneE164,
  }) async {
    final data = await _api.post(ApiConfig.paElectricians, data: {
      'email': email,
      'password': password,
      if (phoneE164 != null && phoneE164.isNotEmpty) 'phone_e164': phoneE164,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getElectricianStats({
    required int electricianId,
    required String preset,
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await _api.get(
      '${ApiConfig.paElectricians}/$electricianId/stats',
      queryParams: {
        'preset': preset,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> startExportResolved({
    required int electricianUserId,
    required String preset,
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await _api.post(ApiConfig.paExportElectricianResolved, data: {
      'electrician_user_id': electricianUserId,
      'preset': preset,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getExportJob(int jobId) async {
    final data = await _api.get(ApiConfig.paExportJob(jobId));
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Uint8List> downloadExportZip(int jobId) async {
    return _api.getBytes(ApiConfig.paExportDownload(jobId));
  }
}
