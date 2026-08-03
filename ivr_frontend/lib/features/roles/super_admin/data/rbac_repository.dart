import 'package:ivr_frontend/core/api/api_client.dart';

import 'models/rbac_analytics.dart';
import 'models/rbac_models.dart';

/// Thin wrapper over `/api/rbac`, the API behind the role management console.
///
/// Distinct from the older `/api/superadmin/roles` endpoints on
/// [SuperAdminRepository]: those wrote role rows that the guards never read.
/// These write `role_screen_access` and `role_permissions`, which are the
/// tables both the sidebar and the API guards actually resolve against.
class RbacRepository {
  final ApiClient _api;

  RbacRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static const String _base = '/api/rbac';

  // ── Catalogue ─────────────────────────────────────────────────────────────

  Future<RbacSummary> getSummary({bool forceRefresh = false}) async {
    final data = await _api.get('$_base/summary', forceRefresh: forceRefresh);
    return RbacSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// The coverage matrix, reach figures, hierarchy, geography and findings
  /// behind the console's insight views.
  Future<RbacAnalytics> getAnalytics({bool forceRefresh = false}) async {
    final data = await _api.get('$_base/analytics', forceRefresh: forceRefresh);
    return RbacAnalytics.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ScreenCatalogue> listScreens({bool forceRefresh = false}) async {
    final data = await _api.get('$_base/screens', forceRefresh: forceRefresh);
    return ScreenCatalogue.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<List<PermissionModule>> listPermissions({bool forceRefresh = false}) async {
    final data = await _api.get('$_base/permissions', forceRefresh: forceRefresh);
    return (data as List)
        .map((e) => PermissionModule.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // ── Roles ─────────────────────────────────────────────────────────────────

  Future<List<RoleSummary>> listRoles({
    String? branchType,
    bool forceRefresh = false,
  }) async {
    final data = await _api.get(
      '$_base/roles',
      queryParams: branchType == null ? null : {'branch_type': branchType},
      forceRefresh: forceRefresh,
    );
    return (data as List)
        .map((e) => RoleSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<RoleDetail> getRole(int roleId) async {
    final data = await _api.get('$_base/roles/$roleId', forceRefresh: true);
    return RoleDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Copy a `__system__` template into this tenant so it can be customised.
  Future<RoleDetail> cloneRole(int roleId, {String? name}) async {
    final data = await _api.post(
      '$_base/roles/$roleId/clone',
      data: {if (name != null && name.trim().isNotEmpty) 'name': name.trim()},
    );
    return RoleDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Replace the role's visible-screen list wholesale.
  Future<RoleDetail> setRoleScreens(int roleId, List<String> screenKeys) async {
    final data = await _api.put(
      '$_base/roles/$roleId/screens',
      data: {'screen_keys': screenKeys},
    );
    return RoleDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Replace the role's permission grants wholesale.
  Future<RoleDetail> setRolePermissions(
    int roleId,
    List<String> permissionCodes,
  ) async {
    final data = await _api.put(
      '$_base/roles/$roleId/permissions',
      data: {'permission_codes': permissionCodes},
    );
    return RoleDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<RoleDetail> setRoleActive(int roleId, bool isActive) async {
    final data = await _api.put(
      '$_base/roles/$roleId/active',
      data: {'is_active': isActive},
    );
    return RoleDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── People ────────────────────────────────────────────────────────────────

  Future<List<RoleMember>> listMembers(int roleId) async {
    final data = await _api.get('$_base/roles/$roleId/members', forceRefresh: true);
    return (data as List)
        .map((e) => RoleMember.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> assignRole({
    required int userId,
    required int roleId,
    required int orgUnitId,
    bool isPrimary = false,
  }) async {
    await _api.post('$_base/assignments', data: {
      'user_id': userId,
      'role_id': roleId,
      'org_unit_id': orgUnitId,
      'is_primary': isPrimary,
    });
  }

  Future<void> revokeAssignment(int assignmentId) async {
    await _api.delete('$_base/assignments/$assignmentId');
  }
}
