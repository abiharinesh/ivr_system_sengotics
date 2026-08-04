import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/models/user_model.dart';

/// The server's verdict on a candidate password.
///
/// Mirrors `PasswordCheck` in `password-policy.ts`. [problems] lists every
/// failing rule rather than the first, so the user can fix them in one pass.
class PasswordVerdict {
  final bool ok;

  /// 0–4. Drives the strength bar.
  final int score;
  final List<String> problems;
  final int minLength;
  final List<String> requirements;

  const PasswordVerdict({
    required this.ok,
    required this.score,
    required this.problems,
    required this.minLength,
    required this.requirements,
  });

  static const empty = PasswordVerdict(
    ok: false,
    score: 0,
    problems: [],
    minLength: 10,
    requirements: [],
  );

  String get label => switch (score) {
        0 => 'Very weak',
        1 => 'Weak',
        2 => 'Fair',
        3 => 'Strong',
        _ => 'Very strong',
      };

  factory PasswordVerdict.fromJson(Map<String, dynamic> json) {
    final check = json['check'] as Map?;
    return PasswordVerdict(
      ok: check?['ok'] == true,
      score: (check?['score'] as num?)?.toInt() ?? 0,
      problems:
          (check?['problems'] as List? ?? []).map((e) => e.toString()).toList(),
      minLength: (json['min_length'] as num?)?.toInt() ?? 10,
      requirements: (json['requirements'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class AuthRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<AuthResponse> login(String email, String password) async {
    final data = await _apiClient.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Set a new password. Returns the reissued token, which no longer asserts
  /// `must_change_password`.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _apiClient.post(
      ApiConfig.changePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return (data as Map<String, dynamic>)['access_token'] as String;
  }

  /// Grade a candidate password server-side.
  ///
  /// The meter reads the same rules the API enforces rather than
  /// reimplementing them, so the form can never accept something that would
  /// then be refused on submit.
  Future<PasswordVerdict> gradePassword(String candidate) async {
    final data = await _apiClient.get(
      ApiConfig.passwordPolicy,
      queryParams: {'candidate': candidate},
      forceRefresh: true,
    );
    return PasswordVerdict.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final data = await _apiClient.post(
      ApiConfig.sendOtp,
      data: {'phone': phone},
    );
    return data as Map<String, dynamic>;
  }

  Future<AuthResponse> verifyOtp(String phone, String otp, {int? orgUnitId}) async {
    final data = await _apiClient.post(
      ApiConfig.verifyOtp,
      data: {
        'phone': phone,
        'otp': otp,
        if (orgUnitId != null) 'org_unit_id': orgUnitId,
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
