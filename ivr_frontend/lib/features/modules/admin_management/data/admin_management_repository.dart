import 'package:ivr_frontend/core/api/api_client.dart';

/// Data layer for the SuperAdmin → Admin Management module.
///
/// Talks to `/api/superadmin/admins` and `/api/superadmin/roles`
/// to create, list, update, and manage admin users with RBAC roles.

class AdminRecord {
  final int id;
  final String? email;
  final String? role;
  final String? phone;
  final bool isActive;
  final bool isVerified;
  final DateTime? lastLoginAt;
  final int? orgUnitId;
  final String? orgUnitName;
  final String? branchType;
  final DateTime createdAt;
  final List<UserRoleRecord> userRoles;

  const AdminRecord({
    required this.id,
    this.email,
    this.role,
    this.phone,
    this.isActive = true,
    this.isVerified = false,
    this.lastLoginAt,
    this.orgUnitId,
    this.orgUnitName,
    this.branchType,
    required this.createdAt,
    this.userRoles = const [],
  });

  factory AdminRecord.fromJson(Map<String, dynamic> j) => AdminRecord(
        id: j['id'] as int,
        email: j['email'] as String?,
        role: j['role'] as String?,
        phone: j['phone_e164'] as String?,
        isActive: j['is_active'] == true,
        isVerified: j['is_verified'] == true,
        lastLoginAt: j['last_login_at'] != null
            ? DateTime.tryParse(j['last_login_at'].toString())
            : null,
        orgUnitId: j['primary_org_unit_id'] as int?,
        orgUnitName: (j['primary_org_unit'] as Map?)?['name'] as String?,
        branchType: (j['primary_org_unit'] as Map?)?['branch_type'] as String?,
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? '') ??
            DateTime.now(),
        userRoles: (j['user_roles'] as List? ?? [])
            .map((e) =>
                UserRoleRecord.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

class UserRoleRecord {
  final int id;
  final int? roleId;
  final String roleName;
  final String roleDisplayName;
  final bool isSuperAdmin;
  final int? orgUnitId;
  final String? orgUnitName;
  final String accessScope;
  final bool isPrimary;
  final bool isTemporary;
  final DateTime? validUntil;

  const UserRoleRecord({
    required this.id,
    this.roleId,
    required this.roleName,
    required this.roleDisplayName,
    this.isSuperAdmin = false,
    this.orgUnitId,
    this.orgUnitName,
    this.accessScope = 'own_org_unit',
    this.isPrimary = false,
    this.isTemporary = false,
    this.validUntil,
  });

  factory UserRoleRecord.fromJson(Map<String, dynamic> j) {
    final role = j['role'] as Map? ?? {};
    final orgUnit = j['org_unit'] as Map? ?? {};
    return UserRoleRecord(
      id: j['id'] as int,
      roleId: role['id'] as int?,
      roleName: role['name'] as String? ?? '',
      roleDisplayName: role['display_name'] as String? ?? '',
      isSuperAdmin: role['is_super_admin'] == true,
      orgUnitId: orgUnit['id'] as int?,
      orgUnitName: orgUnit['name'] as String?,
      accessScope: j['access_scope'] as String? ?? 'own_org_unit',
      isPrimary: j['is_primary'] == true,
      isTemporary: j['is_temporary'] == true,
      validUntil: j['valid_until'] != null
          ? DateTime.tryParse(j['valid_until'].toString())
          : null,
    );
  }
}

class RoleRecord {
  final int id;
  final String name;
  final String displayName;
  final String? displayNameTa;
  final bool isSuperAdmin;
  final bool isActive;
  final int hierarchyLevel;

  const RoleRecord({
    required this.id,
    required this.name,
    required this.displayName,
    this.displayNameTa,
    this.isSuperAdmin = false,
    this.isActive = true,
    this.hierarchyLevel = 5,
  });

  factory RoleRecord.fromJson(Map<String, dynamic> j) => RoleRecord(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        displayNameTa: j['display_name_ta'] as String?,
        isSuperAdmin: j['is_super_admin'] == true,
        isActive: j['is_active'] != false,
        hierarchyLevel: j['hierarchy_level'] as int? ?? 5,
      );
}

class AdminManagementRepository {
  final ApiClient _api;

  AdminManagementRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/superadmin';

  // ── Admin CRUD ──────────────────────────────────────────────────────────

  Future<List<AdminRecord>> listAdmins({
    int? orgUnitId,
    String? role,
    bool? isActive,
  }) async {
    final data = await _api.get(
      '$_base/admins',
      queryParams: {
        if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive.toString(),
      },
      forceRefresh: true,
    );
    return (data as List)
        .map((e) => AdminRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> getAdminDetail(int id) async {
    final data = await _api.get('$_base/admins/$id', forceRefresh: true);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> createAdmin({
    required String email,
    required String password,
    required int orgUnitId,
    required List<int> roleIds,
    String? phone,
    String? accessScope,
    bool? isTemporary,
    String? validUntil,
  }) async {
    final data = await _api.post('$_base/admins', data: {
      'email': email,
      'password': password,
      'org_unit_id': orgUnitId,
      'role_ids': roleIds,
      if (phone != null) 'phone_e164': phone,
      if (accessScope != null) 'access_scope': accessScope,
      if (isTemporary != null) 'is_temporary': isTemporary,
      if (validUntil != null) 'valid_until': validUntil,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> updateAdmin(int id, Map<String, dynamic> body) async {
    final data = await _api.put('$_base/admins/$id', data: body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> toggleAdminStatus(int id, bool isActive) async {
    await _api.patch('$_base/admins/$id/status', data: {'is_active': isActive});
  }

  Future<void> updateAdminRoles(
    int id, {
    required List<int> roleIds,
    required int orgUnitId,
    String? accessScope,
  }) async {
    await _api.patch('$_base/admins/$id/roles', data: {
      'role_ids': roleIds,
      'org_unit_id': orgUnitId,
      if (accessScope != null) 'access_scope': accessScope,
    });
  }

  // ── Roles ──────────────────────────────────────────────────────────────

  Future<List<RoleRecord>> listRoles({int? orgUnitId}) async {
    final data = await _api.get(
      '$_base/roles',
      queryParams: {
        if (orgUnitId != null) 'org_unit_id': orgUnitId.toString(),
      },
      forceRefresh: true,
    );
    return (data as List)
        .map((e) => RoleRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
