/// Models for `/api/rbac/templates` — the shipped role catalogue and what
/// applying it to this tenant would change.
///
/// Every tenant owns copies of the shipped roles rather than sharing rows with
/// anyone else, linked back to the template they came from. That keeps an
/// authorization decision local to the council it applies to, and still lets an
/// improvement to the catalogue reach everyone who has not diverged from it.
library;

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('$v') ?? fallback;
}

List<String> _asStrings(dynamic v) =>
    (v as List?)?.map((e) => '$e').toList() ?? const [];

/// One entry in the shipped catalogue.
class RoleTemplate {
  const RoleTemplate({
    required this.id,
    required this.name,
    required this.displayName,
    required this.displayNameTa,
    required this.department,
    required this.hierarchyLevel,
    required this.applicableBranchTypes,
    required this.screenCount,
    required this.permissionCount,
    required this.inUseBy,
  });

  final int id;
  final String name;
  final String displayName;
  final String? displayNameTa;
  final String? department;
  final int hierarchyLevel;

  /// Which kinds of body this role is offered for. Empty means all of them —
  /// a village panchayat has no Municipal Commissioner.
  final List<String> applicableBranchTypes;

  final int screenCount;
  final int permissionCount;

  /// How many tenants have been provisioned from this template.
  final int inUseBy;

  factory RoleTemplate.fromJson(Map<String, dynamic> json) => RoleTemplate(
        id: _asInt(json['id']),
        name: json['name'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        displayNameTa: json['display_name_ta'] as String?,
        department: json['department'] as String?,
        hierarchyLevel: _asInt(json['hierarchy_level'], 5),
        applicableBranchTypes: _asStrings(json['applicable_branch_types']),
        screenCount: _asInt(json['screen_count']),
        permissionCount: _asInt(json['permission_count']),
        inUseBy: _asInt(json['in_use_by']),
      );
}

/// What a sync would do, or did, to one role.
class SyncOutcome {
  const SyncOutcome({
    required this.roleId,
    required this.name,
    required this.displayName,
    required this.screensAdded,
    required this.screensRemoved,
    required this.permissionsAdded,
    required this.permissionsRemoved,
  });

  final int roleId;
  final String name;
  final String displayName;
  final List<String> screensAdded;
  final List<String> screensRemoved;
  final List<String> permissionsAdded;
  final List<String> permissionsRemoved;

  int get changeCount =>
      screensAdded.length +
      screensRemoved.length +
      permissionsAdded.length +
      permissionsRemoved.length;

  factory SyncOutcome.fromJson(Map<String, dynamic> json) => SyncOutcome(
        roleId: _asInt(json['role_id']),
        name: json['name'] as String? ?? '',
        displayName: json['display_name'] as String? ?? json['name'] as String? ?? '',
        screensAdded: _asStrings(json['screens_added']),
        screensRemoved: _asStrings(json['screens_removed']),
        permissionsAdded: _asStrings(json['permissions_added']),
        permissionsRemoved: _asStrings(json['permissions_removed']),
      );
}

/// A role a sync deliberately left alone.
class SkippedRole {
  const SkippedRole({
    required this.roleId,
    required this.name,
    required this.customisedAt,
  });

  final int roleId;
  final String name;
  final DateTime? customisedAt;

  factory SkippedRole.fromJson(Map<String, dynamic> json) => SkippedRole(
        roleId: _asInt(json['role_id']),
        name: json['name'] as String? ?? '',
        customisedAt: json['customised_at'] == null
            ? null
            : DateTime.tryParse(json['customised_at'].toString()),
      );
}

/// The result of a sync, or of previewing one.
class SyncReport {
  const SyncReport({
    required this.tenantId,
    required this.dryRun,
    required this.updated,
    required this.skippedCustomised,
    required this.unchanged,
    required this.untemplated,
  });

  final String tenantId;

  /// True when nothing was written — the preview the console shows before it
  /// asks anyone to confirm.
  final bool dryRun;

  final List<SyncOutcome> updated;

  /// Roles this council has edited. Reported rather than overwritten: silently
  /// reverting a deliberate decision is worse than leaving it behind, and
  /// unlike being behind, it is invisible until someone loses access.
  final List<SkippedRole> skippedCustomised;

  final int unchanged;

  /// Roles the tenant invented, which have no template to follow.
  final int untemplated;

  bool get hasChanges => updated.isNotEmpty;

  static const empty = SyncReport(
    tenantId: '',
    dryRun: true,
    updated: [],
    skippedCustomised: [],
    unchanged: 0,
    untemplated: 0,
  );

  factory SyncReport.fromJson(Map<String, dynamic> json) => SyncReport(
        tenantId: json['tenant_id'] as String? ?? '',
        dryRun: json['dry_run'] == true,
        updated: (json['updated'] as List? ?? [])
            .map((e) => SyncOutcome.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        skippedCustomised: (json['skipped_customised'] as List? ?? [])
            .map((e) => SkippedRole.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        unchanged: _asInt(json['unchanged']),
        untemplated: _asInt(json['untemplated']),
      );
}

/// How one role differs from the template it was provisioned from.
class TemplateDiff {
  const TemplateDiff({
    required this.roleId,
    required this.name,
    required this.templateName,
    required this.customisedAt,
    required this.screensAdded,
    required this.screensRemoved,
  });

  final int roleId;
  final String name;

  /// Null when the role has no template — one the tenant invented.
  final String? templateName;

  final DateTime? customisedAt;

  /// Screens the template has that this role does not, and the reverse.
  final List<String> screensAdded;
  final List<String> screensRemoved;

  bool get matchesTemplate =>
      screensAdded.isEmpty && screensRemoved.isEmpty;

  factory TemplateDiff.fromJson(Map<String, dynamic> json) => TemplateDiff(
        roleId: _asInt(json['role_id']),
        name: json['name'] as String? ?? '',
        templateName: json['template'] == null
            ? null
            : (json['template'] as Map)['name'] as String?,
        customisedAt: json['customised_at'] == null
            ? null
            : DateTime.tryParse(json['customised_at'].toString()),
        screensAdded: _asStrings(json['screens_added']),
        screensRemoved: _asStrings(json['screens_removed']),
      );
}
