import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/navigation/role_navigation_config.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_models.dart';

/// What a role's sidebar will look like, drawn from the screens it is granted.
///
/// The console is a list of checkboxes against screen keys, which is not what
/// anyone is actually deciding. They are deciding what a health officer sees
/// when they sign in on Monday. Ticking `licence_renewals` and hoping is how
/// roles end up with menus nobody meant.
///
/// Deliberately built with [RoleNavigationConfig.sectionsFrom] — the same
/// function the running app uses — so this cannot drift into showing something
/// the real sidebar would not. A preview that is merely plausible is worse than
/// none, because it will be believed.
class SidebarPreview extends StatelessWidget {
  const SidebarPreview({
    super.key,
    required this.screenKeys,
    required this.catalogue,
    this.roleName,
  });

  /// The keys currently ticked for this role, including unsaved edits.
  final Set<String> screenKeys;

  /// Every screen the platform has, for looking up route, label and icon.
  final ScreenCatalogue catalogue;

  final String? roleName;

  /// The granted screens, in catalogue order.
  ///
  /// The server sorts by `sort_order`; the catalogue endpoint returns screens
  /// grouped and already ordered, so walking it preserves that.
  List<NavScreen> get _resolved => [
        for (final group in catalogue.groups)
          for (final s in group.items)
            if (screenKeys.contains(s.key))
              NavScreen(
                key: s.key,
                route: s.route,
                groupKey: group.groupKey,
                labelEn: s.labelEn,
                labelTa: s.labelTa,
                icon: s.icon,
                sortOrder: s.sortOrder,
              ),
      ];

  @override
  Widget build(BuildContext context) {
    final sections = RoleNavigationConfig.sectionsFrom(_resolved);
    final total = sections.fold<int>(0, (n, s) => n + s.items.length);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 15, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    roleName == null ? 'Their menu' : 'What $roleName sees',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '$total item${total == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.stroke),
          if (sections.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 22),
              child: Column(
                children: [
                  Icon(Icons.remove_circle_outline_rounded,
                      size: 26, color: AppTheme.textMuted),
                  const SizedBox(height: 9),
                  Text(
                    'No menu at all',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Someone with this role signs in and can reach nothing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final section in sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                      child: Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    for (final item in section.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        child: Row(
                          children: [
                            Icon(item.icon, size: 15, color: AppTheme.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
