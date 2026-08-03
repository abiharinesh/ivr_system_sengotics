import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_analytics.dart';

import 'rbac_chart_kit.dart';

/// The console's opening view: the state of access across the whole tenant.
///
/// Ordered by what an administrator does with it — first what is broken, then
/// how access is distributed, then what changed recently. Counts alone were
/// what this screen used to show, and a count of roles tells nobody whether
/// access is set up correctly.
class RbacOverviewPane extends StatelessWidget {
  const RbacOverviewPane({
    super.key,
    required this.analytics,
    this.onOpenRole,
    this.onOpenMatrix,
    this.onOpenGeography,
  });

  final RbacAnalytics analytics;
  final void Function(int roleId)? onOpenRole;
  final VoidCallback? onOpenMatrix;
  final VoidCallback? onOpenGeography;

  @override
  Widget build(BuildContext context) {
    final t = analytics.totals;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _metricGrid(t),
        const SizedBox(height: 16),
        if (analytics.risks.isNotEmpty) _findings(context),
        _distribution(context),
        _hierarchy(context),
        _activity(context),
        if (analytics.roleOverlaps.isNotEmpty) _overlaps(context),
      ],
    );
  }

  // ── Headline figures ───────────────────────────────────────────────────────

  Widget _metricGrid(RbacTotals t) {
    final unreachable =
        analytics.screenReach.where((s) => s.isUnreachable).length;

    final metrics = <Widget>[
      InsightMetric(
        label: 'ROLES',
        value: '${t.roles}',
        icon: Icons.badge_rounded,
        caption: '${t.editableRoles} editable · ${t.inactiveRoles} disabled',
      ),
      InsightMetric(
        label: 'SCREEN COVERAGE',
        value: '${t.screenCoveragePct}',
        suffix: '%',
        icon: Icons.grid_view_rounded,
        emphasis: t.screenCoveragePct >= 90
            ? MetricEmphasis.good
            : t.screenCoveragePct >= 70
                ? MetricEmphasis.warn
                : MetricEmphasis.bad,
        caption: 'of ${t.screens} screens reachable by some role',
        onTap: onOpenMatrix,
      ),
      InsightMetric(
        label: 'ASSIGNMENTS',
        value: '${t.assignments}',
        icon: Icons.link_rounded,
        caption: '${t.activeUsers} active accounts across ${t.branches} branches',
      ),
      InsightMetric(
        label: 'AVG SCREENS / ROLE',
        value: '${t.avgScreensPerRole}',
        icon: Icons.view_sidebar_rounded,
        caption: 'out of ${t.screens} in the catalogue',
      ),
      InsightMetric(
        label: 'PERMISSIONS',
        value: '${t.permissions}',
        icon: Icons.key_rounded,
        caption: 'across ${analytics.permissionDistribution.length} modules',
      ),
      InsightMetric(
        label: 'UNREACHABLE SCREENS',
        value: '$unreachable',
        icon: Icons.block_rounded,
        emphasis: unreachable == 0 ? MetricEmphasis.good : MetricEmphasis.bad,
        caption: unreachable == 0
            ? 'Every screen is granted to someone'
            : 'No role can open these',
        onTap: onOpenMatrix,
      ),
      InsightMetric(
        label: 'NO ROLE',
        value: '${t.usersWithoutRole}',
        icon: Icons.person_off_rounded,
        emphasis:
            t.usersWithoutRole == 0 ? MetricEmphasis.good : MetricEmphasis.bad,
        caption: 'Sign in to an empty menu',
      ),
      InsightMetric(
        label: 'PASSWORD NOT SET',
        value: '${t.usersPendingPasswordChange}',
        icon: Icons.key_off_rounded,
        emphasis: t.usersPendingPasswordChange == 0
            ? MetricEmphasis.good
            : MetricEmphasis.warn,
        caption: 'Still on the issued password',
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth < 560
            ? 2
            : c.maxWidth < 900
                ? 3
                : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: metrics,
        );
      },
    );
  }

  // ── Findings ───────────────────────────────────────────────────────────────

  Widget _findings(BuildContext context) {
    Color colorFor(String severity) => switch (severity) {
          'high' => AppTheme.error,
          'medium' => AppTheme.warning,
          _ => AppTheme.info,
        };
    IconData iconFor(String severity) => switch (severity) {
          'high' => Icons.error_rounded,
          'medium' => Icons.warning_amber_rounded,
          _ => Icons.info_rounded,
        };

    return InsightSection(
      title: 'Findings',
      subtitle: 'Access states that stop somebody working, or that will drift '
          'out of step if left alone.',
      icon: Icons.fact_check_rounded,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${analytics.risks.length}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
      child: Column(
        children: [
          for (final r in analytics.risks)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: colorFor(r.severity).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: colorFor(r.severity).withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(iconFor(r.severity), size: 17, color: colorFor(r.severity)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorFor(r.severity),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${r.count}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          r.detail,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Permission distribution ────────────────────────────────────────────────

  Widget _distribution(BuildContext context) {
    final dist = analytics.permissionDistribution;
    if (dist.isEmpty) return const SizedBox.shrink();
    final max = dist.map((d) => d.grantCount).reduce((a, b) => a > b ? a : b);
    final totalGrants = dist.fold<int>(0, (n, d) => n + d.grantCount);
    final t = analytics.totals;

    return InsightSection(
      title: 'Where authority sits',
      subtitle: 'Total permission grants per module across every role. A tall '
          'bar means many roles can act in that module.',
      icon: Icons.donut_large_rounded,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth > 720;
          final bars = Column(
            children: [
              for (final d in dist.take(wide ? 12 : 8))
                RankedBar(
                  label: prettyKey(d.module),
                  value: d.grantCount,
                  max: max,
                  secondaryLabel:
                      '${d.roleCount} role${d.roleCount == 1 ? '' : 's'} · ${d.permissionCount} perms',
                ),
            ],
          );

          final rings = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProportionRing(
                value: t.permissions == 0
                    ? 0
                    : (totalGrants / (t.permissions * (t.roles == 0 ? 1 : t.roles)))
                        .clamp(0.0, 1.0),
                label: 'Grant density',
                caption: '$totalGrants grants',
                color: AppTheme.primary,
              ),
              const SizedBox(height: 14),
              ProportionRing(
                value: t.screenCoveragePct / 100,
                label: 'Screen coverage',
                caption: '${t.screens} screens',
                color: AppTheme.accent,
                size: 112,
              ),
            ],
          );

          if (!wide) {
            return Column(children: [bars, const SizedBox(height: 18), rings]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: bars),
              const SizedBox(width: 24),
              rings,
            ],
          );
        },
      ),
    );
  }

  // ── Hierarchy ──────────────────────────────────────────────────────────────

  Widget _hierarchy(BuildContext context) {
    if (analytics.hierarchy.isEmpty) return const SizedBox.shrink();
    final maxUsers = analytics.hierarchy
        .map((h) => h.userCount)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return InsightSection(
      title: 'Chain of command',
      subtitle: 'Roles by level, widest where the most people sit. Screens per '
          'role should narrow as you go down, not up.',
      icon: Icons.account_tree_rounded,
      child: Column(
        children: [
          for (final level in analytics.hierarchy)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 108,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          level.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'L${level.level} · ${level.avgScreens} screens avg',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The bar width is the number of people at this level:
                        // a top-heavy shape is an org chart worth questioning.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Stack(
                            children: [
                              Container(height: 10, color: AppTheme.bgSurface),
                              FractionallySizedBox(
                                widthFactor:
                                    (level.userCount / maxUsers).clamp(0.02, 1.0),
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.primary.withValues(alpha: 0.55),
                                        AppTheme.primary,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final role in level.roles)
                              _rolePill(role),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${level.userCount} people',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _rolePill(HierarchyRole role) {
    // An unheld role is drawn faint rather than hidden: it exists, it just has
    // nobody in it, and that is itself worth seeing.
    final held = role.userCount > 0;
    return Tooltip(
      message: '${role.displayName}\n'
          '${role.userCount} holder(s) · ${role.screenCount} screens',
      child: InkWell(
        onTap: onOpenRole == null ? null : () => onOpenRole!(role.roleId),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: held
                ? AppTheme.primary.withValues(alpha: 0.08)
                : AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: held
                  ? AppTheme.primary.withValues(alpha: 0.28)
                  : AppTheme.stroke,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                role.displayName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: held ? AppTheme.textPrimary : AppTheme.textMuted,
                ),
              ),
              if (held) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${role.userCount}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Change history ─────────────────────────────────────────────────────────

  Widget _activity(BuildContext context) {
    final a = analytics.activity;
    final total = a.days.fold<int>(0, (n, d) => n + d.count);
    final fmt = DateFormat('d MMM, h:mm a');

    return InsightSection(
      title: 'Access changes',
      subtitle: 'Every grant, revocation and role edit over the last 30 days. '
          'Each one is written to the audit log and cannot be edited away.',
      icon: Icons.history_rounded,
      trailing: Text(
        '$total in 30 days',
        style: TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActivitySparkline(values: a.days.map((d) => d.count).toList()),
          if (a.byAction.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in a.byAction.take(6))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${prettyKey(e.key)} · ${e.value}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (a.recent.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppTheme.stroke),
            const SizedBox(height: 8),
            for (final e in a.recent.take(8))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: prettyKey(e.action),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            TextSpan(
                              text: '  ${e.entityType} #${e.entityId}',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                            TextSpan(
                              text: '  by ${e.actor}',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      e.createdAt == null ? '' : fmt.format(e.createdAt!.toLocal()),
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ── Near-duplicate roles ───────────────────────────────────────────────────

  Widget _overlaps(BuildContext context) {
    return InsightSection(
      title: 'Near-identical roles',
      subtitle: 'Pairs granting almost the same screens. An access change made '
          'to one and not the other is how they silently drift apart.',
      icon: Icons.compare_arrows_rounded,
      child: Column(
        children: [
          for (final o in analytics.roleOverlaps)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: o.similarity >= 90
                          ? AppTheme.warning.withValues(alpha: 0.18)
                          : AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${o.similarity}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: o.similarity >= 90
                            ? AppTheme.warning
                            : AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${o.aName}  ↔  ${o.bName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${o.shared} shared · ${o.onlyA} only on the first · '
                          '${o.onlyB} only on the second',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onOpenRole != null)
                    TextButton(
                      onPressed: () => onOpenRole!(o.aId),
                      child: const Text('Compare'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
