import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/core/widgets/stat_card.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/models/vital_event_models.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/vital_event_repository.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/widgets/vital_status_badge.dart';

/// The searchable birth & death register.
class VitalEventsRegistryScreen extends StatefulWidget {
  const VitalEventsRegistryScreen({super.key});

  @override
  State<VitalEventsRegistryScreen> createState() =>
      _VitalEventsRegistryScreenState();
}

class _VitalEventsRegistryScreenState extends State<VitalEventsRegistryScreen> {
  final _repo = VitalEventRepository();
  final _searchCtrl = TextEditingController();

  late Future<VitalEventPage> _future;
  Future<VitalEventStats>? _statsFuture;

  VitalEventType? _typeFilter;
  VitalStatus? _statusFilter;
  bool _lateOnly = false;
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
      _future = _repo.listEvents(
        eventType: _typeFilter,
        status: _statusFilter,
        query: _query,
        lateOnly: _lateOnly ? true : null,
        forceRefresh: force,
      );
      _statsFuture = _repo.fetchStats(forceRefresh: force);
    });
  }

  bool get _hasFilters =>
      _typeFilter != null || _statusFilter != null || _lateOnly || _query.isNotEmpty;

  void _clearFilters() {
    _searchCtrl.clear();
    _query = '';
    _typeFilter = null;
    _statusFilter = null;
    _lateOnly = false;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListScreenShell(
      title: 'Birth & death register',
      subtitle: 'Statutory register, certificate issuance and QR verification',
      countLabel: _describeFilters(),
      action: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => context.go('/municipality/vital-events/new?type=DEATH'),
            icon: const Icon(Icons.local_florist_rounded, size: 18),
            label: const Text('Report death'),
          ),
          FilledButton.icon(
            onPressed: () => context.go('/municipality/vital-events/new?type=BIRTH'),
            icon: const Icon(Icons.child_care_rounded, size: 18),
            label: const Text('Report birth'),
          ),
        ],
      ),
      child: FutureBuilder<VitalEventPage>(
        future: _future,
        initialData: _repo.getCachedEvents(
          eventType: _typeFilter,
          status: _statusFilter,
          query: _query,
          lateOnly: _lateOnly ? true : null,
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

          final page = snap.data ?? VitalEventPage.empty;

          return RefreshIndicator(
            onRefresh: () async => _reload(force: true),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FutureBuilder<VitalEventStats>(
                  future: _statsFuture,
                  builder: (context, statsSnap) => _KpiStrip(
                    stats: statsSnap.data ?? VitalEventStats.empty,
                    isLoading: !statsSnap.hasData,
                  ),
                ),
                const SizedBox(height: 20),
                _FilterBar(
                  searchController: _searchCtrl,
                  typeFilter: _typeFilter,
                  statusFilter: _statusFilter,
                  lateOnly: _lateOnly,
                  onSearchSubmitted: (v) {
                    _query = v.trim();
                    _reload();
                  },
                  onTypeChanged: (v) {
                    _typeFilter = v;
                    _reload();
                  },
                  onStatusChanged: (v) {
                    _statusFilter = v;
                    _reload();
                  },
                  onLateToggled: (v) {
                    _lateOnly = v;
                    _reload();
                  },
                  onClear: _hasFilters ? _clearFilters : null,
                ),
                const SizedBox(height: 20),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: AppLoadingState(
                      message: 'Loading register...',
                      skeletonLines: 5,
                      style: AppLoadingStyle.list,
                    ),
                  )
                else if (page.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: AppEmptyState(
                      icon: Icons.menu_book_outlined,
                      title: _hasFilters
                          ? 'No entries match these filters'
                          : 'The register is empty',
                      subtitle: _hasFilters
                          ? 'Try widening the event type or status.'
                          : 'Report a birth or death to make the first entry.',
                      action: _hasFilters
                          ? TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            )
                          : FilledButton.icon(
                              onPressed: () => context.go(
                                '/municipality/vital-events/new?type=BIRTH',
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Report a birth'),
                            ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: page.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _EventRow(event: page.items[i]),
                  ),
                if (page.items.length < page.total)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Showing ${page.items.length} of ${page.total} — narrow the search to see more',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
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

  String _describeFilters() {
    if (!_hasFilters) return 'All entries';
    final parts = <String>[
      if (_typeFilter != null) _typeFilter!.label,
      if (_statusFilter != null) _statusFilter!.label,
      if (_lateOnly) 'Late registrations',
      if (_query.isNotEmpty) '"$_query"',
    ];
    return 'Filtered by ${parts.join(' · ')}';
  }
}

class _KpiStrip extends StatelessWidget {
  final VitalEventStats stats;
  final bool isLoading;

  const _KpiStrip({required this.stats, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 4;
        if (width < 600) {
          columns = 1;
        } else if (width < 960) {
          columns = 2;
        }

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 110,
          ),
          children: [
            StatCard(
              title: 'Births registered',
              value: '${stats.birthsRegistered}',
              icon: Icons.child_care_rounded,
              gradient: AppTheme.primaryGradient,
              isLoading: isLoading,
            ),
            StatCard(
              title: 'Deaths registered',
              value: '${stats.deathsRegistered}',
              icon: Icons.local_florist_rounded,
              gradient: AppTheme.accentGradient,
              isLoading: isLoading,
            ),
            StatCard(
              title: 'Awaiting registrar',
              value: '${stats.pendingAction}',
              icon: Icons.pending_actions_rounded,
              gradient: AppTheme.warningGradient,
              isLoading: isLoading,
            ),
            StatCard(
              title: 'Late registrations',
              value: '${stats.lateRegistrations}',
              icon: Icons.schedule_rounded,
              gradient: AppTheme.errorGradient,
              isLoading: isLoading,
            ),
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final VitalEventType? typeFilter;
  final VitalStatus? statusFilter;
  final bool lateOnly;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<VitalEventType?> onTypeChanged;
  final ValueChanged<VitalStatus?> onStatusChanged;
  final ValueChanged<bool> onLateToggled;
  final VoidCallback? onClear;

  const _FilterBar({
    required this.searchController,
    required this.typeFilter,
    required this.statusFilter,
    required this.lateOnly,
    required this.onSearchSubmitted,
    required this.onTypeChanged,
    required this.onStatusChanged,
    required this.onLateToggled,
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
          width: 300,
          child: TextField(
            controller: searchController,
            onSubmitted: onSearchSubmitted,
            decoration: InputDecoration(
              hintText: 'Reg. no., child, deceased, mother, informant',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 170,
          child: DropdownButtonFormField<VitalEventType?>(
            initialValue: typeFilter,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Event',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            items: [
              const DropdownMenuItem<VitalEventType?>(
                value: null,
                child: Text('Births & deaths'),
              ),
              ...VitalEventType.values.map(
                (t) => DropdownMenuItem<VitalEventType?>(
                  value: t,
                  child: Text(t.label),
                ),
              ),
            ],
            onChanged: onTypeChanged,
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<VitalStatus?>(
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
              const DropdownMenuItem<VitalStatus?>(
                value: null,
                child: Text('All statuses'),
              ),
              ...VitalStatus.values.map(
                (s) => DropdownMenuItem<VitalStatus?>(
                  value: s,
                  child: Text(s.label),
                ),
              ),
            ],
            onChanged: onStatusChanged,
          ),
        ),
        FilterChip(
          label: const Text('Late only'),
          selected: lateOnly,
          onSelected: onLateToggled,
          avatar: const Icon(Icons.schedule_rounded, size: 16),
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

class _EventRow extends StatefulWidget {
  final VitalEventSummary event;

  const _EventRow({required this.event});

  @override
  State<_EventRow> createState() => _EventRowState();
}

class _EventRowState extends State<_EventRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final df = DateFormat.yMMMd();
    final isBirth = e.eventType == VitalEventType.birth;

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
                    VitalStatusBadge.colorFor(e.status).withValues(alpha: 0.14),
                child: Icon(
                  isBirth ? Icons.child_care_rounded : Icons.local_florist_rounded,
                  color: VitalStatusBadge.colorFor(e.status),
                ),
              ),
              title: Text(
                e.registrationNumber != null
                    ? '${e.subjectName} · ${e.registrationNumber}'
                    : e.subjectName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EventTypeChip(type: e.eventType),
                    VitalStatusBadge(status: e.status),
                    if (e.isLateRegistration)
                      DelayBandChip(
                        band: e.delayDays > 365
                            ? DelayBand.magistrateOrder
                            : e.delayDays > 30
                                ? DelayBand.authorityPermission
                                : DelayBand.lateFee,
                        delayDays: e.delayDays,
                      ),
                    Text('${isBirth ? 'Born' : 'Died'} ${df.format(e.eventDate)}'),
                    Text(e.secondaryLine),
                    if (e.placeName != null && e.placeName!.isNotEmpty)
                      Text(e.placeName!),
                    if (e.certificateCount > 0)
                      Text('${e.certificateCount} certificate(s)'),
                  ],
                ),
              ),
              isThreeLine: isNarrow,
              trailing: isNarrow
                  ? null
                  : Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
              onTap: () => context.go('/municipality/vital-events/${e.id}'),
            ),
          ),
        );
      },
    );
  }
}
