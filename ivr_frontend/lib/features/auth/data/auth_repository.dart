import '../../../core/api/api_client.dart';
import '../../../config/api_config.dart';
import '../../../core/models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<AuthResponse> login(String email, String password) async {
    final data = await _apiClient.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final data = await _apiClient.post(
      ApiConfig.sendOtp,
      data: {'phone': phone},
    );
    return data as Map<String, dynamic>;
  }

  Future<AuthResponse> verifyOtp(String phone, String otp, {int? panchayatId}) async {
    final data = await _apiClient.post(
      ApiConfig.verifyOtp,
      data: {
        'phone': phone,
        'otp': otp,
        if (panchayatId != null) 'panchayat_id': panchayatId,
      },
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Switches the active role/org-unit context for a user holding multiple
  /// UserRole assignments — reissues a JWT scoped to the chosen one.
  Future<AuthResponse> switchContext(int userRoleId) async {
    final data = await _apiClient.post(
      ApiConfig.switchContext,
      data: {'user_role_id': userRoleId},
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }
}
