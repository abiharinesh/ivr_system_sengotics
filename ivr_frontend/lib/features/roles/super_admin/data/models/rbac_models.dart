/// Models mirroring the `/api/rbac/*` wire shapes served by
/// `RbacAdminService`. Field names follow the API's snake_case keys rather
/// than being renamed on the way in, so a change on either side shows up as a
/// parse failure here instead of a silently absent value.

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

bool _asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return fallback;
}

DateTime? _asDate(dynamic v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

List<String> _asStringList(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

/// Headline counters across the top of the console.
class RbacSummary {
  final int roles;
  final int screens;
  final int assignments;
  final int usersWithoutRole;
  final int usersPendingPasswordChange;

  const RbacSummary({
    required this.roles,
    required this.screens,
    required this.assignments,
    required this.usersWithoutRole,
    required this.usersPendingPasswordChange,
  });

  factory RbacSummary.fromJson(Map<String, dynamic> json) => RbacSummary(
        roles: _asInt(json['roles']),
        screens: _asInt(json['screens']),
        assignments: _asInt(json['assignments']),
        usersWithoutRole: _asInt(json['users_without_role']),
        usersPendingPasswordChange:
            _asInt(json['users_pending_password_change']),
      );

  static const empty = RbacSummary(
    roles: 0,
    screens: 0,
    assignments: 0,
    usersWithoutRole: 0,
    usersPendingPasswordChange: 0,
  );
}

/// One tickable destination from the `app_screens` catalogue.
class AppScreenInfo {
  final int id;
  final String key;
  final String route;
  final String groupKey;
  final String labelEn;
  final String? labelTa;
  final String icon;
  final String module;
  final String? permissionCode;
  final int sortOrder;
  final bool isPlatformOnly;

  const AppScreenInfo({
    required this.id,
    required this.key,
    required this.route,
    required this.groupKey,
    required this.labelEn,
    required this.labelTa,
    required this.icon,
    required this.module,
    required this.permissionCode,
    required this.sortOrder,
    required this.isPlatformOnly,
  });

  factory AppScreenInfo.fromJson(Map<String, dynamic> json) => AppScreenInfo(
        id: _asInt(json['id']),
        key: json['key'] as String? ?? '',
        route: json['route'] as String? ?? '',
        groupKey: json['group_key'] as String? ?? '',
        labelEn: json['label_en'] as String? ?? '',
        labelTa: json['label_ta'] as String?,
        icon: json['icon'] as String? ?? '',
        module: json['module'] as String? ?? '',
        permissionCode: json['permission_code'] as String?,
        sortOrder: _asInt(json['sort_order']),
        isPlatformOnly: _asBool(json['is_platform_only']),
      );
}

/// Screens under one sidebar group heading, e.g. "REVENUE".
class ScreenGroup {
  final String groupKey;
  final List<AppScreenInfo> items;

  const ScreenGroup({required this.groupKey, required this.items});

  factory ScreenGroup.fromJson(Map<String, dynamic> json) => ScreenGroup(
        groupKey: json['group_key'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((e) => AppScreenInfo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// The full screen catalogue, grouped.
class ScreenCatalogue {
  final int total;
  final List<ScreenGroup> groups;

  const ScreenCatalogue({required this.total, required this.groups});

  factory ScreenCatalogue.fromJson(Map<String, dynamic> json) => ScreenCatalogue(
        total: _asInt(json['total']),
        groups: (json['groups'] as List? ?? [])
            .map((e) => ScreenGroup.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  static const empty = ScreenCatalogue(total: 0, groups: []);

  Iterable<AppScreenInfo> get allScreens => groups.expand((g) => g.items);
}

class PermissionInfo {
  final int id;
  final String code;
  final String module;
  final String action;
  final String? description;

  const PermissionInfo({
    required this.id,
    required this.code,
    required this.module,
    required this.action,
    required this.description,
  });

  factory PermissionInfo.fromJson(Map<String, dynamic> json) => PermissionInfo(
        id: _asInt(json['id']),
        code: json['code'] as String? ?? '',
        module: json['module'] as String? ?? '',
        action: json['action'] as String? ?? '',
        description: json['description'] as String?,
      );
}

/// Permissions belonging to one module, e.g. everything under "complaints".
class PermissionModule {
  final String module;
  final List<PermissionInfo> items;

  const PermissionModule({required this.module, required this.items});

  factory PermissionModule.fromJson(Map<String, dynamic> json) => PermissionModule(
        module: json['module'] as String? ?? '',
        items: (json['items'] as List? ?? [])
            .map((e) => PermissionInfo.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// A role as it appears in the console's left-hand list.
class RoleSummary {
  final int id;
  final String tenantId;
  final String name;
  final String displayName;
  final String? displayNameTa;
  final String? department;
  final int hierarchyLevel;
  final bool isSuperAdmin;
  final bool canApprove;
  final bool isSystem;
  final bool isActive;
  final List<String> applicableBranchTypes;
  final int userCount;
  final int permissionCount;
  final int screenCount;

  const RoleSummary({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.displayName,
    required this.displayNameTa,
    required this.department,
    required this.hierarchyLevel,
    required this.isSuperAdmin,
    required this.canApprove,
    required this.isSystem,
    required this.isActive,
    required this.applicableBranchTypes,
    required this.userCount,
    required this.permissionCount,
    required this.screenCount,
  });

  /// The sentinel tenant holding the shared role templates. A role owned by it
  /// is readable by every tenant and editable by none — see [isEditable].
  static const String systemTenant = '__system__';

  /// `__system__` roles are shared across tenants, so the API refuses to edit
  /// them. The console offers "clone to edit" instead of a disabled form.
  bool get isEditable => tenantId != systemTenant;

  factory RoleSummary.fromJson(Map<String, dynamic> json) => RoleSummary(
        id: _asInt(json['id']),
        tenantId: json['tenant_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        displayNameTa: json['display_name_ta'] as String?,
        department: json['department'] as String?,
        hierarchyLevel: _asInt(json['hierarchy_level'], 5),
        isSuperAdmin: _asBool(json['is_super_admin']),
        canApprove: _asBool(json['can_approve']),
        isSystem: _asBool(json['is_system']),
        isActive: _asBool(json['is_active'], true),
        applicableBranchTypes: _asStringList(json['applicable_branch_types']),
        userCount: _asInt(json['user_count']),
        permissionCount: _asInt(json['permission_count']),
        screenCount: _asInt(json['screen_count']),
      );
}

/// A role with its resolved grants, for the detail pane.
class RoleDetail {
  final RoleSummary role;
  final List<String> permissionCodes;
  final List<String> screenKeys;

  const RoleDetail({
    required this.role,
    required this.permissionCodes,
    required this.screenKeys,
  });

  factory RoleDetail.fromJson(Map<String, dynamic> json) => RoleDetail(
        // `getRole` returns the role's own columns at the top level alongside
        // the resolved grants, so the summary parses from the same map.
        role: RoleSummary.fromJson(json),
        permissionCodes: _asStringList(json['permission_codes']),
        screenKeys: _asStringList(json['screen_keys']),
      );
}

/// A user holding a role, with the branch the grant applies at.
class RoleMember {
  final int assignmentId;
  final int userId;
  final String email;
  final String? phone;
  final bool isUserActive;
  final bool mustChangePassword;
  final DateTime? lastLoginAt;
  final int? orgUnitId;
  final String? orgUnitName;
  final String? branchType;
  final bool isPrimary;
  final String accessScope;

  const RoleMember({
    required this.assignmentId,
    required this.userId,
    required this.email,
    required this.phone,
    required this.isUserActive,
    required this.mustChangePassword,
    required this.lastLoginAt,
    required this.orgUnitId,
    required this.orgUnitName,
    required this.branchType,
    required this.isPrimary,
    required this.accessScope,
  });

  factory RoleMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map? ?? const {};
    final orgUnit = json['org_unit'] as Map?;
    return RoleMember(
      assignmentId: _asInt(json['id']),
      userId: _asInt(json['user_id']),
      email: user['email'] as String? ?? '',
      phone: user['phone_e164'] as String?,
      isUserActive: _asBool(user['is_active'], true),
      mustChangePassword: _asBool(user['must_change_password']),
      lastLoginAt: _asDate(user['last_login_at']),
      orgUnitId: orgUnit == null ? null : _asInt(orgUnit['id']),
      orgUnitName: orgUnit?['name'] as String?,
      branchType: orgUnit?['branch_type'] as String?,
      isPrimary: _asBool(json['is_primary']),
      accessScope: json['access_scope'] as String? ?? 'own_org_unit',
    );
  }
}
