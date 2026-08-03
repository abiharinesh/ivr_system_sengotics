import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_analytics.dart';

import 'rbac_chart_kit.dart';

/// The access matrix: every role against every sidebar group, as a heatmap.
///
/// This is the view that answers "who can see what" without opening thirty
/// role forms one at a time. A pale column is a section of the product nobody
/// can reach; a uniformly dark row is a role that has been handed everything.
class RbacMatrixPane extends StatefulWidget {
  const RbacMatrixPane({
    super.key,
    required this.analytics,
    this.onOpenRole,
  });

  final RbacAnalytics analytics;
  final void Function(int roleId)? onOpenRole;

  @override
  State<RbacMatrixPane> createState() => _RbacMatrixPaneState();
}

class _RbacMatrixPaneState extends State<RbacMatrixPane> {
  String _query = '';
  bool _heldOnly = false;
  String? _focusedGroup;

  static const double _rowHeight = 36;
  static const double _cellWidth = 78;
  static const double _labelWidth = 210;

  @override
  Widget build(BuildContext context) {
    final matrix = widget.analytics.coverage;

    var rows = matrix.roles;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      rows = rows
          .where((r) =>
              r.displayName.toLowerCase().contains(q) ||
              r.name.toLowerCase().contains(q) ||
              (r.department ?? '').toLowerCase().contains(q))
          .toList();
    }
    if (_heldOnly) rows = rows.where((r) => r.userCount > 0).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _controls(rows.length, matrix.roles.length),
        const SizedBox(height: 14),
        InsightSection(
          title: 'Access matrix',
          subtitle: 'Each cell is how much of a sidebar section a role can '
              'open. Tap a row to edit that role.',
          icon: Icons.grid_on_rounded,
          trailing: const CoverageLegend(),
          child: rows.isEmpty
              ? _noRows()
              : _matrix(matrix.groupKeys, rows),
        ),
        _groupTotals(matrix),
        _screenReach(),
      ],
    );
  }

  Widget _controls(int shown, int total) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filter roles by name or department…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: AppTheme.bgCard,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.stroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(color: AppTheme.stroke),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilterChip(
          label: const Text('Held by someone'),
          selected: _heldOnly,
          onSelected: (v) => setState(() => _heldOnly = v),
          showCheckmark: false,
          avatar: Icon(
            Icons.person_rounded,
            size: 15,
            color: _heldOnly ? Colors.white : AppTheme.textMuted,
          ),
          selectedColor: AppTheme.primary,
          labelStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _heldOnly ? Colors.white : AppTheme.textSecondary,
          ),
          backgroundColor: AppTheme.bgCard,
          side: BorderSide(color: AppTheme.stroke),
        ),
        const SizedBox(width: 12),
        Text(
          '$shown of $total',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _noRows() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text(
          'No role matches that filter.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  // ── The heatmap itself ─────────────────────────────────────────────────────

  Widget _matrix(List<String> groups, List<CoverageRow> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(groups),
              const SizedBox(height: 4),
              for (final row in rows) _dataRow(groups, row),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerRow(List<String> groups) {
    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Text(
            'ROLE',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
        ),
        for (final g in groups)
          InkWell(
            onTap: () => setState(
              () => _focusedGroup = _focusedGroup == g ? null : g,
            ),
            child: SizedBox(
              width: _cellWidth,
              height: 46,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Center(
                  child: Text(
                    prettyKey(g),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: _focusedGroup == g
                          ? AppTheme.primary
                          : AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        SizedBox(
          width: 88,
          child: Text(
            'TOTAL',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dataRow(List<String> groups, CoverageRow row) {
    final totalScreens = row.cells.fold<int>(0, (n, c) => n + c.total);
    final overall = totalScreens == 0 ? 0.0 : row.screenCount / totalScreens;

    return InkWell(
      onTap: widget.onOpenRole == null
          ? null
          : () => widget.onOpenRole!(row.roleId),
      child: SizedBox(
        height: _rowHeight,
        child: Row(
          children: [
            SizedBox(
              width: _labelWidth,
              child: Row(
                children: [
                  if (row.isSuperAdmin)
                    const Padding(
                      padding: EdgeInsets.only(right: 5),
                      child: Icon(
                        Icons.shield_rounded,
                        size: 13,
                        color: AppTheme.warning,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      row.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: row.userCount > 0
                            ? AppTheme.textPrimary
                            : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: '${row.userCount} holder(s)',
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 22),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: row.userCount > 0
                            ? AppTheme.primary.withValues(alpha: 0.10)
                            : AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${row.userCount}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: row.userCount > 0
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            for (final g in groups) _cell(row, g),
            SizedBox(
              width: 88,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Stack(
                          children: [
                            Container(height: 6, color: AppTheme.bgSurface),
                            FractionallySizedBox(
                              widthFactor: overall.clamp(0.0, 1.0),
                              child: Container(
                                height: 6,
                                color: coverageColor(overall),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${row.screenCount}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(CoverageRow row, String group) {
    final cell = row.cells.firstWhere(
      (c) => c.groupKey == group,
      orElse: () => CoverageCell(groupKey: group, granted: 0, total: 0),
    );
    final dimmed = _focusedGroup != null && _focusedGroup != group;

    return Tooltip(
      message: '${row.displayName} — ${prettyKey(group)}\n'
          '${cell.granted} of ${cell.total} screens',
      waitDuration: const Duration(milliseconds: 250),
      child: Container(
        width: _cellWidth,
        height: _rowHeight,
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: BoxDecoration(
            color: cell.granted == 0
                ? AppTheme.bgSurface
                : coverageColor(cell.ratio)
                    .withValues(alpha: dimmed ? 0.25 : 1.0),
            borderRadius: BorderRadius.circular(5),
            border: cell.granted == 0
                ? Border.all(color: AppTheme.stroke)
                : null,
          ),
          alignment: Alignment.center,
          child: cell.total == 0
              ? null
              : Text(
                  cell.granted == 0 ? '—' : '${cell.granted}/${cell.total}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: cell.granted == 0
                        ? AppTheme.textMuted
                        : cell.ratio > 0.45
                            ? Colors.white
                            : AppTheme.textPrimary,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Per-group totals ───────────────────────────────────────────────────────

  Widget _groupTotals(CoverageMatrix matrix) {
    if (matrix.groupKeys.isEmpty) return const SizedBox.shrink();

    // How many roles can open at least one screen in each section.
    final counts = <String, int>{};
    for (final g in matrix.groupKeys) {
      counts[g] = matrix.roles
          .where((r) => r.cells.any((c) => c.groupKey == g && c.granted > 0))
          .length;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.isEmpty ? 1 : entries.first.value;

    return InsightSection(
      title: 'Reach by section',
      subtitle: 'How many roles can open at least one screen in each sidebar '
          'section. A short bar is a section only a handful of people ever see.',
      icon: Icons.stacked_bar_chart_rounded,
      child: Column(
        children: [
          for (final e in entries)
            RankedBar(
              label: prettyKey(e.key),
              value: e.value,
              max: max,
              color: e.value == 0 ? AppTheme.error : AppTheme.primary,
              secondaryLabel: 'of ${matrix.roles.length} roles',
              onTap: () => setState(
                () => _focusedGroup = _focusedGroup == e.key ? null : e.key,
              ),
            ),
        ],
      ),
    );
  }

  // ── Screen-level reach ─────────────────────────────────────────────────────

  Widget _screenReach() {
    final reach = [...widget.analytics.screenReach]
      ..sort((a, b) => a.userCount.compareTo(b.userCount));
    if (reach.isEmpty) return const SizedBox.shrink();

    final unreachable = reach.where((s) => s.isUnreachable).toList();
    final thin = reach
        .where((s) => !s.isUnreachable && s.userCount > 0 && s.userCount <= 3)
        .take(8)
        .toList();

    return InsightSection(
      title: 'Screens with the thinnest reach',
      subtitle: 'Destinations only a few people can open. Some of these are '
          'correct; the ones at zero are not.',
      icon: Icons.travel_explore_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unreachable.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.block_rounded,
                          size: 16, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Text(
                        '${unreachable.length} screen(s) no role can open',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in unreachable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.bgCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.stroke),
                          ),
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (final s in thin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${s.userCount}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${prettyKey(s.groupKey)} · via ${s.roleNames.join(', ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
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
}
