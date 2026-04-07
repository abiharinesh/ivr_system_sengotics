import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../config/api_config.dart';
import '../../../models/panchayat_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/user_model.dart';
import '../../../models/stats_model.dart';
import '../../../models/dashboard_insights_model.dart';

class SuperAdminRepository {
  final ApiClient _api = ApiClient.instance;

  // ── Panchayats ──────────────────────────────────────────────────────────
  Future<List<PanchayatModel>> listPanchayats() async {
    final data = await _api.get(ApiConfig.saPanchayats);
    return (data as List).map((j) => PanchayatModel.fromJson(j)).toList();
  }

  Future<PanchayatModel> getPanchayat(int id) async {
    final data = await _api.get('${ApiConfig.saPanchayats}/$id');
    return PanchayatModel.fromJson(data);
  }

  Future<PanchayatModel> createPanchayat(Map<String, dynamic> body) async {
    final data = await _api.post(ApiConfig.saPanchayats, data: body);
    return PanchayatModel.fromJson(data);
  }

  Future<PanchayatModel> updatePanchayat(
    int id,
    Map<String, dynamic> body,
  ) async {
    final data = await _api.put('${ApiConfig.saPanchayats}/$id', data: body);
    return PanchayatModel.fromJson(data);
  }

  Future<void> deletePanchayat(int id) async {
    await _api.delete('${ApiConfig.saPanchayats}/$id');
  }

  // ── Users ───────────────────────────────────────────────────────────────
  Future<List<UserModel>> listUsers() async {
    final data = await _api.get(ApiConfig.saUsers);
    return (data as List).map((j) => UserModel.fromJson(j)).toList();
  }

  Future<UserModel> createUser(Map<String, dynamic> body) async {
    final data = await _api.post(ApiConfig.saUsers, data: body);
    return UserModel.fromJson(data);
  }

  Future<UserModel> createStaffUser(Map<String, dynamic> body) async {
    final data = await _api.post('${ApiConfig.saUsers}/staff', data: body);
    return UserModel.fromJson(data);
  }

  Future<void> deleteUser(int id) async {
    await _api.delete('${ApiConfig.saUsers}/$id');
  }

  // ── Complaints ──────────────────────────────────────────────────────────
  Future<List<ComplaintModel>> listComplaints({
    String? status,
    int? panchayatId,
  }) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (panchayatId != null) params['panchayat_id'] = panchayatId.toString();
    final data = await _api.get(ApiConfig.saComplaints, queryParams: params);
    return (data as List).map((j) => ComplaintModel.fromJson(j)).toList();
  }

  Future<ComplaintModel> updateComplaintStatus(int id, String status) async {
    final data = await _api.patch(
      '${ApiConfig.saComplaints}/$id/status',
      data: {'status': status},
    );
    return ComplaintModel.fromJson(data);
  }

  Future<ComplaintModel> resolveComplaint(int id, int poleId) async {
    final data = await _api.patch(
      '${ApiConfig.saComplaints}/$id/resolve',
      data: {'pole_id': poleId},
    );
    return ComplaintModel.fromJson(data);
  }

  Future<ComplaintModel> assignElectrician(int complaintId, int electricianUserId) async {
    final data = await _api.patch(
      '${ApiConfig.saComplaints}/$complaintId/assign-electrician',
      data: {'electrician_user_id': electricianUserId},
    );
    return ComplaintModel.fromJson(data);
  }

  // ── Poles ───────────────────────────────────────────────────────────────
  Future<List<dynamic>> listPoles({int? panchayatId}) async {
    final params = <String, dynamic>{};
    if (panchayatId != null) params['panchayat_id'] = panchayatId.toString();
    final data = await _api.get(ApiConfig.saPoles, queryParams: params);
    return data as List;
  }

  Future<Map<String, dynamic>> createPole(Map<String, dynamic> body) async {
    final data = await _api.post(ApiConfig.saPoles, data: body);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updatePole(
    int id,
    Map<String, dynamic> body,
  ) async {
    final data = await _api.put('${ApiConfig.saPoles}/$id', data: body);
    return data as Map<String, dynamic>;
  }

  Future<void> deletePole(int id) async {
    await _api.delete('${ApiConfig.saPoles}/$id');
  }

  // ── Stats ───────────────────────────────────────────────────────────────
  Future<StatsModel> getStats() async {
    final data = await _api.get(ApiConfig.saStats);
    return StatsModel.fromJson(data);
  }

  Future<DashboardInsights> getDashboardInsights() async {
    final data = await _api.get(ApiConfig.saDashboardInsights);
    return DashboardInsights.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── AI Providers ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSttProvider() async {
    final data = await _api.get(ApiConfig.saSttProvider);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setSttProvider(String provider) async {
    final data = await _api.put(
      ApiConfig.saSttProvider,
      data: {'provider': provider},
    );
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLlmProvider() async {
    final data = await _api.get(ApiConfig.saLlmProvider);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setLlmProvider(String provider) async {
    final data = await _api.put(
      ApiConfig.saLlmProvider,
      data: {'provider': provider},
    );
    return data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listElectricians({int? panchayatId}) async {
    final data = await _api.get(
      ApiConfig.saElectricians,
      queryParams: panchayatId != null ? {'panchayat_id': panchayatId.toString()} : null,
    );
    return List<dynamic>.from(data as List);
  }

  Future<Map<String, dynamic>> createElectrician({
    required int panchayatId,
    required String email,
    required String password,
    String? phoneE164,
  }) async {
    final data = await _api.post(ApiConfig.saElectricians, data: {
      'panchayat_id': panchayatId,
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
      '${ApiConfig.saElectricians}/$electricianId/stats',
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
    final data = await _api.post(ApiConfig.saExportElectricianResolved, data: {
      'electrician_user_id': electricianUserId,
      'preset': preset,
      if (dateFrom != null) 'date_from': dateFrom,
      if (dateTo != null) 'date_to': dateTo,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> getExportJob(int jobId) async {
    final data = await _api.get(ApiConfig.saExportJob(jobId));
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Uint8List> downloadExportZip(int jobId) async {
    return _api.getBytes(ApiConfig.saExportDownload(jobId));
  }
}
