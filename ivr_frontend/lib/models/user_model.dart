import 'dart:convert';
import 'package:equatable/equatable.dart';

int _jsonInt(dynamic v, [int fallback = 0]) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _jsonIntOpt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

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
      id: _jsonInt(json['id']),
      email: json['email'] as String,
      role: json['role'] as String,
      panchayatId: _jsonIntOpt(json['panchayat_id']),
      panchayatName: json['panchayat']?['name'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
    );
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isPanchayatAdmin => role == 'panchayat_admin';
  bool get isAgent => role == 'agent';
  bool get isElectrician => role == 'electrician';

  /// Panchayat-scoped field roles share the same panchayat_id as admins.
  bool get isFieldStaff => isAgent || isElectrician;

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
        'id': _jsonInt(payload['sub']),
        'email': '${payload['email'] ?? json['email'] ?? ''}',
        'role': '${json['role'] ?? payload['role'] ?? 'user'}',
        'panchayat_id':
            _jsonIntOpt(json['panchayat_id']) ?? _jsonIntOpt(payload['panchayat_id']),
      }),
    );
  }
}
