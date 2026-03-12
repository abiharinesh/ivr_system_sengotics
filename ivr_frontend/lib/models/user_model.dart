import 'dart:convert';
import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final int id;
  final String email;
  final String role;
  final int? panchayatId;
  final String? panchayatName;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.panchayatId,
    this.panchayatName,
    this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String,
      role: json['role'] as String,
      panchayatId: json['panchayat_id'] as int?,
      panchayatName: json['panchayat']?['name'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
    );
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isPanchayatAdmin => role == 'panchayat_admin';

  @override
  List<Object?> get props => [id, email, role, panchayatId];
}

class AuthResponse {
  final String accessToken;
  final UserModel user;

  AuthResponse({required this.accessToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final token = json['access_token'] as String;

    // Decode JWT payload
    final parts = token.split('.');
    Map<String, dynamic> payload = {};
    if (parts.length == 3) {
      final String normalized = base64Url.normalize(parts[1]);
      final String decoded = utf8.decode(base64Url.decode(normalized));
      payload = jsonDecode(decoded);
    }

    return AuthResponse(
      accessToken: token,
      user: UserModel.fromJson({
        'id': payload['sub'] ?? 0,
        'email': payload['email'] ?? '',
        'role': json['role'] ?? payload['role'] ?? 'user',
        'panchayat_id': json['panchayat_id'] ?? payload['panchayat_id'],
      }),
    );
  }
}
