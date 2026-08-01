import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/app_status_badge.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/features/modules/tenders/data/models/tender_models.dart';
import 'package:ivr_frontend/features/modules/tenders/data/tender_repository.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/widgets/tender_filter_bar.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/widgets/tender_grid_card.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/widgets/tender_kpi_section.dart';

class TenderListScreen extends StatefulWidget {
  final bool isSuperAdmin;
  const TenderListScreen({super.key, this.isSuperAdmin = false});

  @override
  State<TenderListScreen> createState() => _TenderListScreenState();
}

class _TenderListScreenState extends State<TenderListScreen> {
  late final TenderRepository _repo;
  String? _statusFilter;
  int? _panchayatFilter;
  List<dynamic>? _panchayats;
  late Future<List<TenderSummary>> _future;

  String _searchQuery = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _repo = TenderRepository(isSuperAdmin: widget.isSuperAdmin);
    _future = _repo.listTenders();
    if (widget.isSuperAdmin) {
      SuperAdminRepository().listPanchayats().then((list) {
        if (mounted) {
          setState(() {
            _panchayats = list;
          });
        }
      });
    }
  }

  void _reload() {
    setState(() {
      _future = _repo.listTenders(
        status: _statusFilter,
        orgUnitId: _panchayatFilter,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListScreenShell(
      title: 'Tenders',
      subtitle: 'Manage lifecycle from draft to closure',
      countLabel:
          _statusFilter == null
              ? 'All tenders'
              : 'Filtered by ${_statusFilter!.replaceAll('_', ' ')}',
      action: FilledButton.icon(
        onPressed:
            () => context.go(
              widget.isSuperAdmin ? '/superadmin/tenders/new' : '/tenders/new',
            ),
        icon: const Icon(Icons.add),
        label: const Text('New tender'),
      ),
      child: FutureBuilder<List<TenderSummary>>(
        future: _future,
        initialData: _repo.getCachedTenders(
          status: _statusFilter,
          orgUnitId: _panchayatFilter,
        ),
        builder: (context, snap) {
          final isLoading = snap.connectionState == ConnectionState.waiting && !snap.hasData;
          if (snap.hasError) {
            return AppErrorState(
              message: userFacingMessage(snap.error!),
              onRetry: _reload,
            );
          }

          final allTenders = snap.data ?? [];

          // Apply client-side search query filtering
          var filteredTenders = allTenders;
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            filteredTenders =
                allTenders.where((t) {
                  final title = (t.titleEn ?? t.titleTa ?? '').toLowerCase();
                  final idStr = t.id.toString();
                  return title.contains(query) || idStr.contains(query);
                }).toList();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              // Responsive: always use list view if screen is very narrow (mobile)
              final bool renderGrid = _isGridView && width > 560;

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  // 1. KPI statistics Section
                  TenderKpiSection(tenders: allTenders, isLoading: isLoading),
                  const SizedBox(height: 20),

                  // 2. Search & Filter Control Bar
                  TenderFilterBar(
                    searchQuery: _searchQuery,
                    onSearchChanged: isLoading ? (_) {} : (val) {
                      setState(() => _searchQuery = val);
                    },
                    statusFilter: _statusFilter,
                    onStatusChanged: isLoading ? (_) {} : (val) {
                      setState(() => _statusFilter = val);
                      _reload();
                    },
                    panchayatFilter: _panchayatFilter,
                    onPanchayatChanged:
                        widget.isSuperAdmin && !isLoading
                            ? (val) {
                              setState(() => _panchayatFilter = val);
                              _reload();
                            }
                            : null,
                    panchayats: _panchayats,
                    isGridView: _isGridView,
                    onViewToggle: isLoading ? () {} : () {
                      setState(() => _isGridView = !_isGridView);
                    },
                  ),
                  const SizedBox(height: 20),

                  // 3. Grid or List of Tenders
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: AppLoadingState(
                        message: 'Loading tenders...',
                        skeletonLines: 5,
                        style: AppLoadingStyle.list,
                      ),
                    )
                  else if (filteredTenders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: AppEmptyState(
                        icon: Icons.assignment_outlined,
                        title:
                            _searchQuery.isNotEmpty
                                ? 'No matches found'
                                : 'No tenders yet',
                        subtitle:
                            _searchQuery.isNotEmpty
                                ? 'Try refining your search query keyword.'
                                : 'Create your first tender to get started.',
                        action:
                            _searchQuery.isNotEmpty
                                ? TextButton(
                                  onPressed: () {
                                    setState(() => _searchQuery = '');
                                  },
                                  child: const Text('Clear search'),
                                )
                                : FilledButton.icon(
                                  onPressed:
                                      () => context.go(
                                        widget.isSuperAdmin
                                            ? '/superadmin/tenders/new'
                                            : '/tenders/new',
                                      ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create tender'),
                                ),
                      ),
                    )
                  else if (renderGrid)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTenders.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: width > 960 ? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.25,
                      ),
                      itemBuilder: (context, i) {
                        return TenderGridCard(
                          t: filteredTenders[i],
                          isSuperAdmin: widget.isSuperAdmin,
                        );
                      },
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredTenders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder:
                          (context, i) => _TenderRow(
                            t: filteredTenders[i],
                            isSuperAdmin: widget.isSuperAdmin,
                          ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TenderRow extends StatefulWidget {
  final TenderSummary t;
  final bool isSuperAdmin;
  const _TenderRow({required this.t, required this.isSuperAdmin});

  @override
  State<_TenderRow> createState() => _TenderRowState();
}

class _TenderRowState extends State<_TenderRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    final t = widget.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isInvited = t.quotationAccessMode == 'invited_only';
    final accessChip = Chip(
      label: Text(
        isInvited ? 'Invited' : 'Open',
        style: TextStyle(
          color:
              isInvited
                  ? (isDark
                      ? Colors.blueGrey.shade200
                      : Colors.blueGrey.shade800)
                  : (isDark ? Colors.green.shade200 : Colors.green.shade800),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
      backgroundColor:
          isInvited
              ? (isDark
                  ? Colors.blueGrey.shade900.withValues(alpha: 0.6)
                  : Colors.blueGrey.shade100)
              : (isDark
                  ? Colors.green.shade900.withValues(alpha: 0.6)
                  : Colors.lightGreen.shade100),
      side: BorderSide(
        color:
            isInvited
                ? (isDark ? Colors.blueGrey.shade800 : Colors.blueGrey.shade200)
                : (isDark ? Colors.green.shade800 : Colors.green.shade200),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 560;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(
              horizontal: isNarrow ? 4 : 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color:
                  _hovered
                      ? AppTheme.primary.withValues(alpha: 0.04)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color:
                    _hovered
                        ? AppTheme.primary.withValues(alpha: 0.18)
                        : Colors.transparent,
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 16,
                vertical: 4,
              ),
              leading: const CircleAvatar(
                child: Icon(Icons.assignment_outlined),
              ),
              title: Text(
                (t.titleEn ?? t.titleTa ?? 'Tender #${t.id}'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppStatusBadge(status: t.status),
                    if (widget.isSuperAdmin && t.orgUnitName != null)
                      Chip(
                        label: Text(
                          t.orgUnitName!,
                          style: TextStyle(
                            color:
                                isDark
                                    ? Colors.purple.shade200
                                    : Colors.purple.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor:
                            isDark
                                ? Colors.purple.shade900.withValues(alpha: 0.6)
                                : Colors.purple.shade50,
                        side: BorderSide(
                          color:
                              isDark
                                  ? Colors.purple.shade800
                                  : Colors.purple.shade200,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (t.status == 'field_verification' &&
                        t.verificationProgress != null &&
                        t.verificationProgress!.total > 0)
                      Chip(
                        label: Text(
                          'Verification: ${t.verificationProgress!.done}/${t.verificationProgress!.total}',
                          style: TextStyle(
                            color:
                                isDark
                                    ? Colors.teal.shade200
                                    : Colors.teal.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor:
                            isDark
                                ? Colors.teal.shade900.withValues(alpha: 0.6)
                                : Colors.teal.shade50,
                        side: BorderSide(
                          color:
                              isDark
                                  ? Colors.teal.shade800
                                  : Colors.teal.shade200,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    if (t.anchorDate != null)
                      Text('Anchor: ${df.format(t.anchorDate!)}'),
                    Text('Items: ${t.lineItemsCount}'),
                    Text('Quotes: ${t.quotationsCount}'),
                    Text('Docs: ${t.documentsCount}'),
                    if (isNarrow) accessChip,
                  ],
                ),
              ),
              trailing: isNarrow ? null : accessChip,
              isThreeLine: isNarrow,
              onTap:
                  () => context.go(
                    widget.isSuperAdmin
                        ? '/superadmin/tenders/${t.id}'
                        : '/tenders/${t.id}',
                  ),
            ),
          ),
        );
      },
    );
  }
}
