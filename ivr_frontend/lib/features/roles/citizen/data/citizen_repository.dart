import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/core/models/pole_model.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/complaint_model.dart';

class CitizenRepository {
  final ApiClient _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> listPanchayats() async {
    final data = await _api.get(ApiConfig.citizenPanchayats);
    return (data as List).map((j) => Map<String, dynamic>.from(j as Map)).toList();
  }

  Future<AuthResponse> registerCitizen({
    required String email,
    required String password,
    required int orgUnitId,
    String? phone,
  }) async {
    final data = await _api.post(
      ApiConfig.citizenRegister,
      data: {
        'email': email,
        'password_hash': password, // Backend hashes this string
        'org_unit_id': orgUnitId,
        if (phone != null && phone.isNotEmpty) 'phone_e164': phone,
      },
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PoleModel>> listPoles() async {
    final data = await _api.get(ApiConfig.citizenPoles, forceRefresh: true);
    return (data as List).map((j) => PoleModel.fromJson(j)).toList();
  }

  Future<List<ComplaintModel>> listComplaints() async {
    final data = await _api.get(ApiConfig.citizenComplaints, forceRefresh: true);
    return (data as List).map((j) => ComplaintModel.fromJson(j)).toList();
  }

  Future<ComplaintModel> raiseComplaint({
    required int poleId,
    required String complaintType,
    required String description,
    required String urgencyLevel,
  }) async {
    final data = await _api.post(
      ApiConfig.citizenComplaints,
      data: {
        'pole_id': poleId,
        'complaint_type': complaintType,
        'description': description,
        'urgency_level': urgencyLevel,
      },
    );
    return ComplaintModel.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getIvrHistory() async {
    final data = await _api.get(ApiConfig.publicIvrSync);
    return Map<String, dynamic>.from(data as Map);
  }
}
