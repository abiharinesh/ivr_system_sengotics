import '../../../core/api/api_client.dart';
import '../../../config/api_config.dart';
import '../../../models/user_model.dart';
import '../../../models/complaint_model.dart';
import '../../../models/pole_model.dart';
import '../../../models/stats_model.dart';

class PanchayatAdminRepository {
  final ApiClient _api = ApiClient.instance;

  // ── Profile ─────────────────────────────────────────────────────────────
  Future<UserModel> getMe() async {
    final data = await _api.get(ApiConfig.paMe);
    return UserModel.fromJson(data);
  }

  // ── Stats ───────────────────────────────────────────────────────────────
  Future<StatsModel> getStats() async {
    final data = await _api.get(ApiConfig.paStats);
    return StatsModel.fromJson(data);
  }

  // ── Poles ───────────────────────────────────────────────────────────────
  Future<List<PoleModel>> listPoles() async {
    final data = await _api.get(ApiConfig.paPoles);
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
  Future<List<ComplaintModel>> listComplaints({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final data = await _api.get(ApiConfig.paComplaints, queryParams: params);
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
}
