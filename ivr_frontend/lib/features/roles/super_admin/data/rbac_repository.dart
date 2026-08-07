import 'package:ivr_frontend/core/api/api_client.dart';

import 'models/rbac_analytics.dart';
import 'models/rbac_models.dart';
import 'models/role_template_models.dart';

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

  /// Define a role this tenant invents.
  ///
  /// It starts with no grants at all. A new designation that could see
  /// everything by default would be a way to escalate by creating rather than
  /// by being granted, so screens and permissions are ticked on afterwards.
  ///
  /// The server owns the rules — a name that collides with a shipped role,
  /// hierarchy level 0, an empty display name — and returns them as messages.
  /// They are not restated here, where they would drift.
  Future<RoleDetail> createRole({
    required String name,
    required String displayName,
    String? displayNameTa,
    String? department,
    int? hierarchyLevel,
    bool canApprove = false,
    List<String> applicableBranchTypes = const [],
  }) async {
    final data = await _api.post('$_base/roles', data: {
      'name': name.trim(),
      'display_name': displayName.trim(),
      if (displayNameTa != null && displayNameTa.trim().isNotEmpty)
        'display_name_ta': displayNameTa.trim(),
      if (department != null && department.trim().isNotEmpty)
        'department': department.trim(),
      if (hierarchyLevel != null) 'hierarchy_level': hierarchyLevel,
      'can_approve': canApprove,
      if (applicableBranchTypes.isNotEmpty)
        'applicable_branch_types': applicableBranchTypes,
    });
    return RoleDetail.fromJson(Map<String, dynamic>.from(data as Map));
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  /// The shipped catalogue, and how many tenants use each entry.
  Future<List<RoleTemplate>> listTemplates({
    String? branchType,
    bool forceRefresh = false,
  }) async {
    final data = await _api.get(
      '$_base/templates',
      queryParams: branchType == null ? null : {'branch_type': branchType},
      forceRefresh: forceRefresh,
    );
    return (data as List)
        .map((e) => RoleTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// What a sync would change, without changing it.
  Future<SyncReport> pendingSync({bool forceRefresh = true}) async {
    final data = await _api.get('$_base/templates/pending', forceRefresh: forceRefresh);
    return SyncReport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Bring this tenant's untouched roles back in line with the catalogue.
  ///
  /// Roles the tenant has edited come back in `skippedCustomised` rather than
  /// being overwritten.
  Future<SyncReport> syncTemplates({List<int>? roleIds, bool dryRun = false}) async {
    final data = await _api.post('$_base/templates/sync', data: {
      if (roleIds != null && roleIds.isNotEmpty) 'role_ids': roleIds,
      'dry_run': dryRun,
    });
    return SyncReport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// How one role differs from the template it came from.
  Future<TemplateDiff> templateDiff(int roleId) async {
    final data =
        await _api.get('$_base/roles/$roleId/template-diff', forceRefresh: true);
    return TemplateDiff.fromJson(Map<String, dynamic>.from(data as Map));
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
