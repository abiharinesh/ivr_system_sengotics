import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/rbac_analytics.dart';

import 'rbac_chart_kit.dart';

/// Access plotted geographically: which branches are staffed, which roles are
/// deployed where, and how much of the product each branch's people can
/// actually reach.
///
/// Plotted with a painter over the branches' own coordinates rather than a
/// tiled map. The question here is relative — which branch is thin next to its
/// neighbours — and that reads better without streets underneath it. It also
/// means the view works with no map key and no network tiles.
class RbacGeographyPane extends StatefulWidget {
  const RbacGeographyPane({super.key, required this.analytics});

  final RbacAnalytics analytics;

  @override
  State<RbacGeographyPane> createState() => _RbacGeographyPaneState();
}

class _RbacGeographyPaneState extends State<RbacGeographyPane> {
  int? _selectedId;
  _Measure _measure = _Measure.coverage;

  @override
  Widget build(BuildContext context) {
    final branches =
        widget.analytics.branchMap.where((b) => b.hasLocation).toList();
    final all = widget.analytics.branchMap;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _summaryRow(all),
        const SizedBox(height: 16),
        InsightSection(
          title: 'Deployment map',
          subtitle: 'One marker per branch, positioned by its own coordinates. '
              'Size is the number of staff; colour is the chosen measure.',
          icon: Icons.public_rounded,
          trailing: _measureToggle(),
          child: branches.isEmpty
              ? _noGeo()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 380,
                      child: _BranchMap(
                        branches: branches,
                        measure: _measure,
                        selectedId: _selectedId,
                        onSelect: (id) => setState(
                          () => _selectedId = _selectedId == id ? null : id,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CoverageLegend(label: _measure.legendLabel),
                        const Spacer(),
                        Text(
                          '${branches.length} branch(es) plotted',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        if (_selectedId != null) _detail(all),
        _branchTable(all),
        _byType(all),
      ],
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  Widget _summaryRow(List<BranchAccess> branches) {
    final staffed = branches.where((b) => b.userCount > 0).length;
    final unstaffed = branches.length - staffed;
    final avgCoverage = branches.isEmpty
        ? 0
        : (branches.fold<int>(0, (n, b) => n + b.coveragePct) / branches.length)
            .round();
    final thinnest = branches.isEmpty
        ? null
        : branches.reduce((a, b) => a.coveragePct <= b.coveragePct ? a : b);

    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth < 560 ? 2 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            InsightMetric(
              label: 'BRANCHES',
              value: '${branches.length}',
              icon: Icons.account_balance_rounded,
              caption: '$staffed staffed',
            ),
            InsightMetric(
              label: 'UNSTAFFED',
              value: '$unstaffed',
              icon: Icons.person_off_rounded,
              emphasis:
                  unstaffed == 0 ? MetricEmphasis.good : MetricEmphasis.bad,
              caption: unstaffed == 0
                  ? 'Every branch has someone'
                  : 'Nobody is assigned here',
            ),
            InsightMetric(
              label: 'AVG COVERAGE',
              value: '$avgCoverage',
              suffix: '%',
              icon: Icons.donut_small_rounded,
              emphasis: avgCoverage >= 70
                  ? MetricEmphasis.good
                  : avgCoverage >= 40
                      ? MetricEmphasis.warn
                      : MetricEmphasis.bad,
              caption: 'of the product reachable per branch',
            ),
            InsightMetric(
              label: 'THINNEST',
              value: thinnest == null ? '—' : '${thinnest.coveragePct}%',
              icon: Icons.trending_down_rounded,
              emphasis: MetricEmphasis.warn,
              caption: thinnest?.name ?? '',
            ),
          ],
        );
      },
    );
  }

  Widget _measureToggle() {
    return SegmentedButton<_Measure>(
      segments: const [
        ButtonSegment(
          value: _Measure.coverage,
          label: Text('Coverage', style: TextStyle(fontSize: 11.5)),
        ),
        ButtonSegment(
          value: _Measure.staff,
          label: Text('Staff', style: TextStyle(fontSize: 11.5)),
        ),
        ButtonSegment(
          value: _Measure.roles,
          label: Text('Roles', style: TextStyle(fontSize: 11.5)),
        ),
      ],
      selected: {_measure},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _measure = s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _noGeo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'No branch has coordinates recorded yet.',
          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  // ── Selected branch ────────────────────────────────────────────────────────

  Widget _detail(List<BranchAccess> all) {
    final b = all.where((x) => x.orgUnitId == _selectedId).firstOrNull;
    if (b == null) return const SizedBox.shrink();

    return InsightSection(
      title: b.name,
      subtitle: '${prettyKey(b.branchType)}'
          '${b.district == null ? '' : ' · ${b.district} district'}'
          '${b.wardCount == null ? '' : ' · ${b.wardCount} wards'}',
      icon: Icons.location_on_rounded,
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        onPressed: () => setState(() => _selectedId = null),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProportionRing(
                value: b.coveragePct / 100,
                label: 'Reachable',
                caption: '${b.screenReach}/${b.screenTotal}',
                size: 112,
                color: coverageColor(b.coveragePct / 100),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statLine('Staff assigned', '${b.userCount}'),
                    _statLine('Distinct roles', '${b.roleCount}'),
                    _statLine('Role assignments', '${b.assignmentCount}'),
                    _statLine('Status', prettyKey(b.branchStatus)),
                  ],
                ),
              ),
            ],
          ),
          if (b.topRoles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'SENIOR ROLES PRESENT',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in b.topRoles)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      r,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _branchTable(List<BranchAccess> branches) {
    final sorted = [...branches]
      ..sort((a, b) => a.coveragePct.compareTo(b.coveragePct));

    return InsightSection(
      title: 'Branch by branch',
      subtitle: 'Weakest coverage first — the branches whose staff can open the '
          'least of the product.',
      icon: Icons.table_rows_rounded,
      child: Column(
        children: [
          for (final b in sorted)
            InkWell(
              onTap: () => setState(
                () => _selectedId = _selectedId == b.orgUnitId ? null : b.orgUnitId,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedId == b.orgUnitId
                      ? AppTheme.primary.withValues(alpha: 0.06)
                      : AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: _selectedId == b.orgUnitId
                        ? AppTheme.primary.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: coverageColor(b.coveragePct / 100),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            prettyKey(b.branchType),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _tableCell('${b.userCount}', 'staff'),
                    _tableCell('${b.roleCount}', 'roles'),
                    _tableCell('${b.screenReach}', 'screens'),
                    SizedBox(
                      width: 84,
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: Stack(
                                children: [
                                  Container(height: 6, color: AppTheme.bgElevated),
                                  FractionallySizedBox(
                                    widthFactor:
                                        (b.coveragePct / 100).clamp(0.0, 1.0),
                                    child: Container(
                                      height: 6,
                                      color: coverageColor(b.coveragePct / 100),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 30,
                            child: Text(
                              '${b.coveragePct}%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableCell(String value, String label) {
    return SizedBox(
      width: 58,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // ── By body type ───────────────────────────────────────────────────────────

  Widget _byType(List<BranchAccess> branches) {
    if (branches.isEmpty) return const SizedBox.shrink();
    final byType = <String, List<BranchAccess>>{};
    for (final b in branches) {
      byType.putIfAbsent(b.branchType, () => []).add(b);
    }
    final entries = byType.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final max = entries.first.value
        .fold<int>(0, (n, b) => n + b.userCount)
        .clamp(1, 1 << 30);

    return InsightSection(
      title: 'By body type',
      subtitle: 'Staffing across corporations, municipalities, town panchayats '
          'and unions. Roles differ by type, so coverage should too.',
      icon: Icons.apartment_rounded,
      child: Column(
        children: [
          for (final e in entries)
            RankedBar(
              label: prettyKey(e.key),
              value: e.value.fold<int>(0, (n, b) => n + b.userCount),
              max: max,
              secondaryLabel:
                  '${e.value.length} branch(es) · avg ${(e.value.fold<int>(0, (n, b) => n + b.coveragePct) / e.value.length).round()}% coverage',
            ),
        ],
      ),
    );
  }
}

enum _Measure {
  coverage('Coverage'),
  staff('Staff'),
  roles('Roles');

  const _Measure(this.legendLabel);
  final String legendLabel;
}

/// Scatter of branches in their own lat/lng space.
class _BranchMap extends StatelessWidget {
  const _BranchMap({
    required this.branches,
    required this.measure,
    required this.selectedId,
    required this.onSelect,
  });

  final List<BranchAccess> branches;
  final _Measure measure;
  final int? selectedId;
  final void Function(int id) onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final layout = _MapLayout(
          branches: branches,
          size: Size(c.maxWidth, c.maxHeight),
        );

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: _GridPainter(layout: layout)),
                ),
                for (final b in branches)
                  _marker(b, layout.offsetFor(b), layout.radiusFor(b)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _marker(BranchAccess b, Offset at, double radius) {
    final selected = selectedId == b.orgUnitId;
    final color = switch (measure) {
      _Measure.coverage => coverageColor(b.coveragePct / 100),
      _Measure.staff => coverageColor(
          (b.userCount / 12).clamp(0.0, 1.0).toDouble(),
        ),
      _Measure.roles => coverageColor(
          (b.roleCount / 10).clamp(0.0, 1.0).toDouble(),
        ),
    };
    final value = switch (measure) {
      _Measure.coverage => '${b.coveragePct}%',
      _Measure.staff => '${b.userCount}',
      _Measure.roles => '${b.roleCount}',
    };

    return Positioned(
      left: at.dx - radius,
      top: at.dy - radius,
      child: Tooltip(
        message: '${b.name}\n'
            '${b.userCount} staff · ${b.roleCount} roles · '
            '${b.coveragePct}% of screens reachable',
        child: GestureDetector(
          onTap: () => onSelect(b.orgUnitId),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: AppTheme.durationFast,
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: selected ? 0.95 : 0.72),
                border: Border.all(
                  color: selected ? AppTheme.textPrimary : Colors.white,
                  width: selected ? 2.5 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: selected ? 18 : 8,
                    spreadRadius: selected ? 2 : 0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: radius > 22 ? 12 : 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Projects lat/lng into the available box, keeping a margin so markers near
/// the edge are not clipped.
class _MapLayout {
  _MapLayout({required this.branches, required this.size}) {
    final lats = branches.map((b) => b.lat!).toList();
    final lngs = branches.map((b) => b.lng!).toList();
    minLat = lats.reduce(math.min);
    maxLat = lats.reduce(math.max);
    minLng = lngs.reduce(math.min);
    maxLng = lngs.reduce(math.max);
    // A single branch, or several at the same point, would give a zero span.
    if ((maxLat - minLat).abs() < 0.01) {
      minLat -= 0.05;
      maxLat += 0.05;
    }
    if ((maxLng - minLng).abs() < 0.01) {
      minLng -= 0.05;
      maxLng += 0.05;
    }
    maxStaff = branches
        .map((b) => b.userCount)
        .fold<int>(1, (a, b) => a > b ? a : b);
  }

  final List<BranchAccess> branches;
  final Size size;
  late double minLat, maxLat, minLng, maxLng;
  late int maxStaff;

  static const double margin = 56;

  Offset offsetFor(BranchAccess b) {
    final w = size.width - margin * 2;
    final h = size.height - margin * 2;
    final x = margin + ((b.lng! - minLng) / (maxLng - minLng)) * w;
    // Latitude increases northward, screen y increases downward.
    final y = margin + (1 - (b.lat! - minLat) / (maxLat - minLat)) * h;
    return Offset(x, y);
  }

  double radiusFor(BranchAccess b) {
    final t = maxStaff == 0 ? 0.0 : b.userCount / maxStaff;
    return 15 + t * 16;
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.layout});

  final _MapLayout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppTheme.stroke.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    // A light graticule so the markers read as positions rather than a
    // free-floating bubble chart.
    const divisions = 6;
    for (var i = 0; i <= divisions; i++) {
      final x = size.width * (i / divisions);
      final y = size.height * (i / divisions);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Faint connecting lines between branches, ordered west to east, to hint
    // at the district's shape.
    final ordered = [...layout.branches]
      ..sort((a, b) => a.lng!.compareTo(b.lng!));
    if (ordered.length > 1) {
      final path = Path();
      final first = layout.offsetFor(ordered.first);
      path.moveTo(first.dx, first.dy);
      for (final b in ordered.skip(1)) {
        final o = layout.offsetFor(b);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppTheme.primary.withValues(alpha: 0.18),
      );
    }

    // Corner coordinate labels, so the plot is anchored to real geography.
    void label(String text, Offset at, {bool rightAlign = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, rightAlign ? at.translate(-tp.width, 0) : at);
    }

    label('${layout.maxLat.toStringAsFixed(2)}°N', const Offset(8, 6));
    label(
      '${layout.minLat.toStringAsFixed(2)}°N',
      Offset(8, size.height - 18),
    );
    label(
      '${layout.minLng.toStringAsFixed(2)}°E',
      Offset(8, size.height - 32),
    );
    label(
      '${layout.maxLng.toStringAsFixed(2)}°E',
      Offset(size.width - 8, size.height - 18),
      rightAlign: true,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.layout != layout;
}
