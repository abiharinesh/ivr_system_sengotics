import '../../../core/api/api_client.dart';
import '../../../config/api_config.dart';
import '../../../models/panchayat_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/user_model.dart';
import '../../../models/stats_model.dart';

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
}
