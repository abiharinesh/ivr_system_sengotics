import 'models/rbac_models.dart';

/// A tick-list of grant keys held against what the server last confirmed.
///
/// The console edits screens and permissions as whole sets and PUTs the result,
/// so the interesting state is not "what is ticked" but "what is ticked that
/// was not before". Keeping [saved] alongside [selected] is what lets the UI
/// show an accurate unsaved-changes count and offer a discard that means
/// something, rather than re-fetching to find out what changed.
class GrantSelection {
  /// What the server last returned for this role.
  final Set<String> saved;

  /// What the operator has ticked, including unsaved edits.
  final Set<String> selected;

  const GrantSelection._(this.saved, this.selected);

  /// A clean selection: nothing edited yet.
  factory GrantSelection.from(Iterable<String> saved) {
    final set = Set<String>.unmodifiable(saved);
    return GrantSelection._(set, set);
  }

  static final GrantSelection empty = GrantSelection.from(const <String>[]);

  bool contains(String key) => selected.contains(key);

  bool get isDirty =>
      selected.length != saved.length || !selected.containsAll(saved);

  /// Keys ticked since the last save.
  Set<String> get added => selected.difference(saved);

  /// Keys unticked since the last save.
  Set<String> get removed => saved.difference(selected);

  int get changeCount => added.length + removed.length;

  /// Sorted so a diff of two audit-log entries is readable.
  List<String> get payload => selected.toList()..sort();

  GrantSelection toggle(String key, bool on) {
    if (selected.contains(key) == on) return this;
    final next = Set<String>.of(selected);
    if (on) {
      next.add(key);
    } else {
      next.remove(key);
    }
    return GrantSelection._(saved, next);
  }

  /// Tick or untick a whole group at once — the "select all in REVENUE" case.
  GrantSelection setAll(Iterable<String> keys, bool on) {
    final next = Set<String>.of(selected);
    if (on) {
      next.addAll(keys);
    } else {
      next.removeAll(keys);
    }
    return GrantSelection._(saved, next);
  }

  /// Throw away unsaved edits.
  GrantSelection reset() => GrantSelection._(saved, saved);

  /// Accept the server's response as the new baseline after a successful save.
  GrantSelection commit(Iterable<String> confirmed) => GrantSelection.from(confirmed);
}

/// Whether a role may be granted a screen at all.
///
/// Mirrors the rule `RbacAdminService.setRoleScreens` enforces: platform-only
/// screens administer the platform itself, so only a super-admin role may hold
/// them. Checking it here too means the checkbox is disabled with a reason
/// rather than the whole save failing on one bad tick.
bool screenGrantableTo(AppScreenInfo screen, RoleSummary role) =>
    !screen.isPlatformOnly || role.isSuperAdmin;

/// Case-insensitive match across the fields an operator would search by.
bool _screenMatches(AppScreenInfo s, String q) =>
    s.labelEn.toLowerCase().contains(q) ||
    s.key.toLowerCase().contains(q) ||
    s.module.toLowerCase().contains(q) ||
    s.groupKey.toLowerCase().contains(q) ||
    (s.labelTa?.contains(q) ?? false);

/// Narrow the screen catalogue to a search term, dropping groups left empty.
List<ScreenGroup> filterScreenGroups(List<ScreenGroup> groups, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return groups;

  final out = <ScreenGroup>[];
  for (final g in groups) {
    final items = g.items.where((s) => _screenMatches(s, q)).toList();
    if (items.isNotEmpty) {
      out.add(ScreenGroup(groupKey: g.groupKey, items: items));
    }
  }
  return out;
}

/// Narrow the permission catalogue to a search term, dropping empty modules.
List<PermissionModule> filterPermissionModules(
  List<PermissionModule> modules,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return modules;

  final out = <PermissionModule>[];
  for (final m in modules) {
    final items = m.items
        .where((p) =>
            p.code.toLowerCase().contains(q) ||
            p.module.toLowerCase().contains(q) ||
            p.action.toLowerCase().contains(q) ||
            (p.description?.toLowerCase().contains(q) ?? false))
        .toList();
    if (items.isNotEmpty) {
      out.add(PermissionModule(module: m.module, items: items));
    }
  }
  return out;
}

/// Narrow the role list to what the operator is looking at.
///
/// [branchType] drops roles that do not exist at that kind of body — an empty
/// `applicable_branch_types` means "every type", matching the server.
List<RoleSummary> filterRoles(
  List<RoleSummary> roles, {
  String query = '',
  String? branchType,
  bool includeSystem = true,
}) {
  final q = query.trim().toLowerCase();
  return roles.where((r) {
    if (!includeSystem && !r.isEditable) return false;
    if (branchType != null &&
        r.applicableBranchTypes.isNotEmpty &&
        !r.applicableBranchTypes.contains(branchType)) {
      return false;
    }
    if (q.isEmpty) return true;
    return r.displayName.toLowerCase().contains(q) ||
        r.name.toLowerCase().contains(q) ||
        (r.department?.toLowerCase().contains(q) ?? false) ||
        (r.displayNameTa?.contains(q) ?? false);
  }).toList();
}

/// Why a role cannot be disabled, or null if it can be.
///
/// Reproduces the server's refusal so the console can grey the switch out with
/// the reason attached, instead of letting the operator flip it and read the
/// failure in a snackbar.
String? disableBlockedReason(RoleSummary role) {
  if (!role.isEditable) {
    return '"${role.displayName}" is a shared system role. Clone it to change it.';
  }
  if (role.userCount > 0) {
    return '${role.userCount} user(s) still hold this role. Reassign them first.';
  }
  return null;
}
