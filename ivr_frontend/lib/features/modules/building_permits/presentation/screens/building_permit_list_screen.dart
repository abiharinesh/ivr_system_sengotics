import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/building_permit_repository.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/widgets/permit_kpi_section.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/widgets/permit_status_badge.dart';

/// Building permit register — the town planning office's working list.
class BuildingPermitListScreen extends StatefulWidget {
  const BuildingPermitListScreen({super.key});

  @override
  State<BuildingPermitListScreen> createState() =>
      _BuildingPermitListScreenState();
}

class _BuildingPermitListScreenState extends State<BuildingPermitListScreen> {
  final _repo = BuildingPermitRepository();
  final _searchCtrl = TextEditingController();

  late Future<BuildingPermitPage> _future;
  Future<BuildingPermitStats>? _statsFuture;

  PermitStatus? _statusFilter;
  String? _typeFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload({bool force = false}) {
    setState(() {
      _future = _repo.listPermits(
        status: _statusFilter?.wire,
        constructionType: _typeFilter,
        query: _query,
        forceRefresh: force,
      );
      _statsFuture = _repo.fetchStats(forceRefresh: force);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListScreenShell(
      title: 'Building permits',
      subtitle: 'Plan approvals, department clearances and site inspections',
      countLabel: _describeFilters(),
      action: FilledButton.icon(
        onPressed: () => context.go('/municipality/building-permits/new'),
        icon: const Icon(Icons.add),
        label: const Text('New application'),
      ),
      child: FutureBuilder<BuildingPermitPage>(
        future: _future,
        initialData: _repo.getCachedPermits(
          status: _statusFilter?.wire,
          constructionType: _typeFilter,
          query: _query,
        ),
        builder: (context, snap) {
          final isLoading =
              snap.connectionState == ConnectionState.waiting && !snap.hasData;

          if (snap.hasError) {
            return AppErrorState(
              message: userFacingMessage(snap.error!),
              onRetry: () => _reload(force: true),
            );
          }

          final page = snap.data ?? BuildingPermitPage.empty;

          return RefreshIndicator(
            onRefresh: () async => _reload(force: true),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FutureBuilder<BuildingPermitStats>(
                  future: _statsFuture,
                  builder: (context, statsSnap) => PermitKpiSection(
                    stats: statsSnap.data ?? BuildingPermitStats.empty,
                    isLoading: !statsSnap.hasData,
                  ),
                ),
                const SizedBox(height: 20),
                _FilterBar(
                  searchController: _searchCtrl,
                  statusFilter: _statusFilter,
                  typeFilter: _typeFilter,
                  onSearchSubmitted: (value) {
                    _query = value.trim();
                    _reload();
                  },
                  onStatusChanged: (value) {
                    _statusFilter = value;
                    _reload();
                  },
                  onTypeChanged: (value) {
                    _typeFilter = value;
                    _reload();
                  },
                  onClear: _hasFilters
                      ? () {
                          _searchCtrl.clear();
                          _query = '';
                          _statusFilter = null;
                          _typeFilter = null;
                          _reload();
                        }
                      : null,
                ),
                const SizedBox(height: 20),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: AppLoadingState(
                      message: 'Loading permit register...',
                      skeletonLines: 5,
                      style: AppLoadingStyle.list,
                    ),
                  )
                else if (page.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: AppEmptyState(
                      icon: Icons.domain_add_outlined,
                      title: _hasFilters
                          ? 'No permits match these filters'
                          : 'No building permit applications yet',
                      subtitle: _hasFilters
                          ? 'Try widening the status or construction type.'
                          : 'Register the first plan approval application to get started.',
                      action: _hasFilters
                          ? TextButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                _query = '';
                                _statusFilter = null;
                                _typeFilter = null;
                                _reload();
                              },
                              child: const Text('Clear filters'),
                            )
                          : FilledButton.icon(
                              onPressed: () =>
                                  context.go('/municipality/building-permits/new'),
                              icon: const Icon(Icons.add),
                              label: const Text('New application'),
                            ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _PermitRow(permit: page.items[i]),
                  ),
                if (page.items.length < page.total)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Showing ${page.items.length} of ${page.total} — refine the filters to narrow this down',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool get _hasFilters =>
      _statusFilter != null || _typeFilter != null || _query.isNotEmpty;

  String _describeFilters() {
    if (!_hasFilters) return 'All applications';
    final parts = <String>[
      if (_statusFilter != null) _statusFilter!.label,
      if (_typeFilter != null) titleCase(_typeFilter!),
      if (_query.isNotEmpty) '"$_query"',
    ];
    return 'Filtered by ${parts.join(' · ')}';
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final PermitStatus? statusFilter;
  final String? typeFilter;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<PermitStatus?> onStatusChanged;
  final ValueChanged<String?> onTypeChanged;
  final VoidCallback? onClear;

  const _FilterBar({
    required this.searchController,
    required this.statusFilter,
    required this.typeFilter,
    required this.onSearchSubmitted,
    required this.onStatusChanged,
    required this.onTypeChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: searchController,
            onSubmitted: onSearchSubmitted,
            decoration: InputDecoration(
              hintText: 'Permit no., applicant, survey no.',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<PermitStatus?>(
            initialValue: statusFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Status',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            items: [
              const DropdownMenuItem<PermitStatus?>(
                value: null,
                child: Text('All statuses'),
              ),
              ...PermitStatus.values.map(
                (s) => DropdownMenuItem<PermitStatus?>(
                  value: s,
                  child: Text(s.label),
                ),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String?>(
            initialValue: typeFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Construction type',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All types'),
              ),
              ...kConstructionTypes.map(
                (t) => DropdownMenuItem<String?>(
                  value: t,
                  child: Text(titleCase(t)),
                ),
              ),
            ],
            onChanged: onTypeChanged,
          ),
        ),
        if (onClear != null)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Clear'),
          ),
      ],
    );
  }
}

class _PermitRow extends StatefulWidget {
  final BuildingPermitSummary permit;

  const _PermitRow({required this.permit});

  @override
  State<_PermitRow> createState() => _PermitRowState();
}

class _PermitRowState extends State<_PermitRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.permit;
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final df = DateFormat.yMMMd();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;

        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8, vertical: 4),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _hovered
                    ? AppTheme.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor:
                    PermitStatusBadge.colorFor(p.status).withValues(alpha: 0.14),
                child: Icon(
                  Icons.home_work_outlined,
                  color: PermitStatusBadge.colorFor(p.status),
                ),
              ),
              title: Text(
                '${p.applicantName} · ${p.permitNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PermitStatusBadge(status: p.status),
                    Text(p.siteLabel),
                    Text(
                      '${titleCase(p.constructionType)} · '
                      '${p.builtUpAreaSqm.toStringAsFixed(0)} sqm · '
                      '${p.floorsProposed} floor${p.floorsProposed == 1 ? '' : 's'}',
                    ),
                    if (p.nocsTotal > 0)
                      Text('NOC ${p.nocsGranted}/${p.nocsTotal}'),
                    Text(
                      p.paymentStatus == 'paid'
                          ? 'Fee paid ${money.format(p.totalFee)}'
                          : 'Due ${money.format(p.totalFee - p.paidAmount)}',
                      style: TextStyle(
                        color: p.paymentStatus == 'paid'
                            ? AppTheme.accent
                            : AppTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (p.submittedAt != null)
                      Text('Filed ${df.format(p.submittedAt!)}'),
                  ],
                ),
              ),
              isThreeLine: isNarrow,
              trailing: isNarrow
                  ? null
                  : Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
              onTap: () => context.go('/municipality/building-permits/${p.id}'),
            ),
          ),
        );
      },
    );
  }
}
