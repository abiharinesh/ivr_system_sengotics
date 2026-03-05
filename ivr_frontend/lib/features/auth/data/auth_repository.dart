import '../../../core/api/api_client.dart';
import '../../../config/api_config.dart';
import '../../../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<AuthResponse> login(String email, String password) async {
    final data = await _apiClient.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }
}
