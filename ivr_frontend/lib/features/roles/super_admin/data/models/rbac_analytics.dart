/// Models for `GET /api/rbac/analytics` — the payload behind the console's
/// insight views.
///
/// Kept separate from [rbac_models.dart] because these are read-only
/// projections: nothing here is ever posted back, so none of it carries the
/// identifiers the editing panes need.

int _int(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double? _doubleOrNull(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool _bool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) return v == 'true';
  return fallback;
}

List<String> _strings(dynamic v) =>
    v is List ? v.map((e) => e.toString()).toList() : const [];

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.map((e) => Map<String, dynamic>.from(e as Map)).toList()
    : const [];

/// Headline figures across the top of every insight view.
class RbacTotals {
  final int roles;
  final int editableRoles;
  final int inactiveRoles;
  final int screens;
  final int permissions;
  final int assignments;
  final int users;
  final int activeUsers;
  final int branches;
  final int avgScreensPerRole;
  final int screenCoveragePct;
  final int usersWithoutRole;
  final int usersPendingPasswordChange;

  const RbacTotals({
    required this.roles,
    required this.editableRoles,
    required this.inactiveRoles,
    required this.screens,
    required this.permissions,
    required this.assignments,
    required this.users,
    required this.activeUsers,
    required this.branches,
    required this.avgScreensPerRole,
    required this.screenCoveragePct,
    required this.usersWithoutRole,
    required this.usersPendingPasswordChange,
  });

  factory RbacTotals.fromJson(Map<String, dynamic> j) => RbacTotals(
        roles: _int(j['roles']),
        editableRoles: _int(j['editable_roles']),
        inactiveRoles: _int(j['inactive_roles']),
        screens: _int(j['screens']),
        permissions: _int(j['permissions']),
        assignments: _int(j['assignments']),
        users: _int(j['users']),
        activeUsers: _int(j['active_users']),
        branches: _int(j['branches']),
        avgScreensPerRole: _int(j['avg_screens_per_role']),
        screenCoveragePct: _int(j['screen_coverage_pct']),
        usersWithoutRole: _int(j['users_without_role']),
        usersPendingPasswordChange: _int(j['users_pending_password_change']),
      );

  static const empty = RbacTotals(
    roles: 0,
    editableRoles: 0,
    inactiveRoles: 0,
    screens: 0,
    permissions: 0,
    assignments: 0,
    users: 0,
    activeUsers: 0,
    branches: 0,
    avgScreensPerRole: 0,
    screenCoveragePct: 0,
    usersWithoutRole: 0,
    usersPendingPasswordChange: 0,
  );
}

/// One cell of the coverage matrix: how much of a sidebar group a role sees.
class CoverageCell {
  final String groupKey;
  final int granted;
  final int total;

  const CoverageCell({
    required this.groupKey,
    required this.granted,
    required this.total,
  });

  /// 0…1. Drives the cell's colour intensity.
  double get ratio => total == 0 ? 0 : granted / total;

  factory CoverageCell.fromJson(Map<String, dynamic> j) => CoverageCell(
        groupKey: j['group_key'] as String? ?? '',
        granted: _int(j['granted']),
        total: _int(j['total']),
      );
}

/// One row of the coverage matrix.
class CoverageRow {
  final int roleId;
  final String name;
  final String displayName;
  final int hierarchyLevel;
  final String? department;
  final bool isSuperAdmin;
  final bool isEditable;
  final int userCount;
  final int screenCount;
  final int permissionCount;
  final List<CoverageCell> cells;

  const CoverageRow({
    required this.roleId,
    required this.name,
    required this.displayName,
    required this.hierarchyLevel,
    required this.department,
    required this.isSuperAdmin,
    required this.isEditable,
    required this.userCount,
    required this.screenCount,
    required this.permissionCount,
    required this.cells,
  });

  factory CoverageRow.fromJson(Map<String, dynamic> j) => CoverageRow(
        roleId: _int(j['role_id']),
        name: j['name'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        hierarchyLevel: _int(j['hierarchy_level'], 5),
        department: j['department'] as String?,
        isSuperAdmin: _bool(j['is_super_admin']),
        isEditable: _bool(j['is_editable'], true),
        userCount: _int(j['user_count']),
        screenCount: _int(j['screen_count']),
        permissionCount: _int(j['permission_count']),
        cells: _maps(j['cells']).map(CoverageCell.fromJson).toList(),
      );
}

class CoverageMatrix {
  final List<String> groupKeys;
  final List<CoverageRow> roles;

  const CoverageMatrix({required this.groupKeys, required this.roles});

  factory CoverageMatrix.fromJson(Map<String, dynamic> j) => CoverageMatrix(
        groupKeys: _strings(j['group_keys']),
        roles: _maps(j['roles']).map(CoverageRow.fromJson).toList(),
      );

  static const empty = CoverageMatrix(groupKeys: [], roles: []);
}

/// How many roles and people can actually open one screen.
class ScreenReach {
  final int screenId;
  final String key;
  final String label;
  final String groupKey;
  final String module;
  final bool isPlatformOnly;
  final int roleCount;
  final int userCount;
  final List<String> roleNames;

  const ScreenReach({
    required this.screenId,
    required this.key,
    required this.label,
    required this.groupKey,
    required this.module,
    required this.isPlatformOnly,
    required this.roleCount,
    required this.userCount,
    required this.roleNames,
  });

  /// Nobody can open it. A screen in this state is dead weight in the product.
  bool get isUnreachable => roleCount == 0 && !isPlatformOnly;

  factory ScreenReach.fromJson(Map<String, dynamic> j) => ScreenReach(
        screenId: _int(j['screen_id']),
        key: j['key'] as String? ?? '',
        label: j['label'] as String? ?? '',
        groupKey: j['group_key'] as String? ?? '',
        module: j['module'] as String? ?? '',
        isPlatformOnly: _bool(j['is_platform_only']),
        roleCount: _int(j['role_count']),
        userCount: _int(j['user_count']),
        roleNames: _strings(j['role_names']),
      );
}

class ModulePermissionStat {
  final String module;
  final int permissionCount;
  final int grantCount;
  final int roleCount;

  const ModulePermissionStat({
    required this.module,
    required this.permissionCount,
    required this.grantCount,
    required this.roleCount,
  });

  factory ModulePermissionStat.fromJson(Map<String, dynamic> j) =>
      ModulePermissionStat(
        module: j['module'] as String? ?? '',
        permissionCount: _int(j['permission_count']),
        grantCount: _int(j['grant_count']),
        roleCount: _int(j['role_count']),
      );
}

class HierarchyRole {
  final int roleId;
  final String displayName;
  final int userCount;
  final int screenCount;

  const HierarchyRole({
    required this.roleId,
    required this.displayName,
    required this.userCount,
    required this.screenCount,
  });

  factory HierarchyRole.fromJson(Map<String, dynamic> j) => HierarchyRole(
        roleId: _int(j['role_id']),
        displayName: j['display_name'] as String? ?? '',
        userCount: _int(j['user_count']),
        screenCount: _int(j['screen_count']),
      );
}

/// One rung of the chain of command.
class HierarchyLevel {
  final int level;
  final String label;
  final int roleCount;
  final int userCount;
  final int avgScreens;
  final List<HierarchyRole> roles;

  const HierarchyLevel({
    required this.level,
    required this.label,
    required this.roleCount,
    required this.userCount,
    required this.avgScreens,
    required this.roles,
  });

  factory HierarchyLevel.fromJson(Map<String, dynamic> j) => HierarchyLevel(
        level: _int(j['level']),
        label: j['label'] as String? ?? '',
        roleCount: _int(j['role_count']),
        userCount: _int(j['user_count']),
        avgScreens: _int(j['avg_screens']),
        roles: _maps(j['roles']).map(HierarchyRole.fromJson).toList(),
      );
}

/// Access as deployed at one branch — the geographic view.
class BranchAccess {
  final int orgUnitId;
  final String name;
  final String branchType;
  final String branchStatus;
  final String? district;
  final double? lat;
  final double? lng;
  final int? wardCount;
  final int roleCount;
  final int userCount;
  final int assignmentCount;
  final int screenReach;
  final int screenTotal;
  final int coveragePct;
  final List<String> topRoles;

  const BranchAccess({
    required this.orgUnitId,
    required this.name,
    required this.branchType,
    required this.branchStatus,
    required this.district,
    required this.lat,
    required this.lng,
    required this.wardCount,
    required this.roleCount,
    required this.userCount,
    required this.assignmentCount,
    required this.screenReach,
    required this.screenTotal,
    required this.coveragePct,
    required this.topRoles,
  });

  bool get hasLocation => lat != null && lng != null;

  factory BranchAccess.fromJson(Map<String, dynamic> j) => BranchAccess(
        orgUnitId: _int(j['org_unit_id']),
        name: j['name'] as String? ?? '',
        branchType: j['branch_type'] as String? ?? '',
        branchStatus: j['branch_status'] as String? ?? '',
        district: j['district'] as String?,
        lat: _doubleOrNull(j['lat']),
        lng: _doubleOrNull(j['lng']),
        wardCount: j['ward_count'] == null ? null : _int(j['ward_count']),
        roleCount: _int(j['role_count']),
        userCount: _int(j['user_count']),
        assignmentCount: _int(j['assignment_count']),
        screenReach: _int(j['screen_reach']),
        screenTotal: _int(j['screen_total']),
        coveragePct: _int(j['coverage_pct']),
        topRoles: _strings(j['top_roles']),
      );
}

/// Two roles granting nearly the same screens.
class RoleOverlap {
  final int aId;
  final String aName;
  final int bId;
  final String bName;
  final int shared;
  final int onlyA;
  final int onlyB;
  final int similarity;

  const RoleOverlap({
    required this.aId,
    required this.aName,
    required this.bId,
    required this.bName,
    required this.shared,
    required this.onlyA,
    required this.onlyB,
    required this.similarity,
  });

  factory RoleOverlap.fromJson(Map<String, dynamic> j) => RoleOverlap(
        aId: _int(j['a_id']),
        aName: j['a_name'] as String? ?? '',
        bId: _int(j['b_id']),
        bName: j['b_name'] as String? ?? '',
        shared: _int(j['shared']),
        onlyA: _int(j['only_a']),
        onlyB: _int(j['only_b']),
        similarity: _int(j['similarity']),
      );
}

/// Something an administrator should look at.
class RbacRisk {
  final String severity; // high | medium | low
  final String code;
  final String title;
  final String detail;
  final int count;

  const RbacRisk({
    required this.severity,
    required this.code,
    required this.title,
    required this.detail,
    required this.count,
  });

  factory RbacRisk.fromJson(Map<String, dynamic> j) => RbacRisk(
        severity: j['severity'] as String? ?? 'low',
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        count: _int(j['count']),
      );
}

class ActivityDay {
  final String date;
  final int count;

  const ActivityDay({required this.date, required this.count});

  factory ActivityDay.fromJson(Map<String, dynamic> j) => ActivityDay(
        date: j['date'] as String? ?? '',
        count: _int(j['count']),
      );
}

class ActivityEntry {
  final String action;
  final String entityType;
  final String entityId;
  final String actor;
  final DateTime? createdAt;

  const ActivityEntry({
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.actor,
    required this.createdAt,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> j) => ActivityEntry(
        action: j['action'] as String? ?? '',
        entityType: j['entity_type'] as String? ?? '',
        entityId: j['entity_id'] as String? ?? '',
        actor: j['actor'] as String? ?? 'system',
        createdAt: DateTime.tryParse(j['created_at']?.toString() ?? ''),
      );
}

class RbacActivity {
  final List<ActivityDay> days;
  final List<MapEntry<String, int>> byAction;
  final List<ActivityEntry> recent;

  const RbacActivity({
    required this.days,
    required this.byAction,
    required this.recent,
  });

  factory RbacActivity.fromJson(Map<String, dynamic> j) => RbacActivity(
        days: _maps(j['days']).map(ActivityDay.fromJson).toList(),
        byAction: _maps(j['by_action'])
            .map((e) => MapEntry(e['action'] as String? ?? '', _int(e['count'])))
            .toList(),
        recent: _maps(j['recent']).map(ActivityEntry.fromJson).toList(),
      );

  static const empty = RbacActivity(days: [], byAction: [], recent: []);
}

/// The whole analytics payload.
class RbacAnalytics {
  final DateTime? generatedAt;
  final RbacTotals totals;
  final CoverageMatrix coverage;
  final List<ScreenReach> screenReach;
  final List<ModulePermissionStat> permissionDistribution;
  final List<HierarchyLevel> hierarchy;
  final List<BranchAccess> branchMap;
  final List<RoleOverlap> roleOverlaps;
  final List<RbacRisk> risks;
  final RbacActivity activity;

  const RbacAnalytics({
    required this.generatedAt,
    required this.totals,
    required this.coverage,
    required this.screenReach,
    required this.permissionDistribution,
    required this.hierarchy,
    required this.branchMap,
    required this.roleOverlaps,
    required this.risks,
    required this.activity,
  });

  factory RbacAnalytics.fromJson(Map<String, dynamic> j) => RbacAnalytics(
        generatedAt: DateTime.tryParse(j['generated_at']?.toString() ?? ''),
        totals: RbacTotals.fromJson(_map(j['totals'])),
        coverage: CoverageMatrix.fromJson(_map(j['coverage'])),
        screenReach: _maps(j['screen_reach']).map(ScreenReach.fromJson).toList(),
        permissionDistribution: _maps(j['permission_distribution'])
            .map(ModulePermissionStat.fromJson)
            .toList(),
        hierarchy: _maps(j['hierarchy']).map(HierarchyLevel.fromJson).toList(),
        branchMap: _maps(j['branch_map']).map(BranchAccess.fromJson).toList(),
        roleOverlaps: _maps(j['role_overlaps']).map(RoleOverlap.fromJson).toList(),
        risks: _maps(j['risks']).map(RbacRisk.fromJson).toList(),
        activity: RbacActivity.fromJson(_map(j['activity'])),
      );

  static const empty = RbacAnalytics(
    generatedAt: null,
    totals: RbacTotals.empty,
    coverage: CoverageMatrix.empty,
    screenReach: [],
    permissionDistribution: [],
    hierarchy: [],
    branchMap: [],
    roleOverlaps: [],
    risks: [],
    activity: RbacActivity.empty,
  );

  bool get isEmpty => totals.roles == 0 && coverage.roles.isEmpty;
}
