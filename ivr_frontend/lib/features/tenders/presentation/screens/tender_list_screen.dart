import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/app_theme.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/list_screen_shell.dart';
import '../../../super_admin/data/super_admin_repository.dart';
import '../../data/models/tender_models.dart';
import '../../data/tender_repository.dart';

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
  late Future<List<TenderSummary>> _future;

  @override
  void initState() {
    super.initState();
    _repo = TenderRepository(isSuperAdmin: widget.isSuperAdmin);
    _future = _repo.listTenders();
  }

  void _reload() {
    setState(() {
      _future = _repo.listTenders(status: _statusFilter, panchayatId: _panchayatFilter);
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
        onPressed: () => context.go(widget.isSuperAdmin ? '/superadmin/tenders/new' : '/tenders/new'),
        icon: const Icon(Icons.add),
        label: const Text('New tender'),
      ),
      filters: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String?>(
            value: _statusFilter,
            hint: const Text('All statuses'),
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
              DropdownMenuItem(value: 'published', child: Text('Published')),
              DropdownMenuItem(
                value: 'quotations_closed',
                child: Text('Quotations closed'),
              ),
              DropdownMenuItem(
                value: 'vendor_selected',
                child: Text('Vendor selected'),
              ),
              DropdownMenuItem(
                value: 'field_verification',
                child: Text('Field verification'),
              ),
              DropdownMenuItem(value: 'closed', child: Text('Closed')),
            ],
            onChanged: (v) {
              setState(() => _statusFilter = v);
              _reload();
            },
          ),
          if (widget.isSuperAdmin) ...[
            const SizedBox(width: 12),
            FutureBuilder<List<dynamic>>(
              future: SuperAdminRepository().listPanchayats(),
              builder: (context, snap) {
                final list = snap.data ?? [];
                return DropdownButton<int?>(
                  value: _panchayatFilter,
                  hint: const Text('All Panchayats'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Panchayats')),
                    ...list.map((p) => DropdownMenuItem(
                      value: p.id as int,
                      child: Text(p.name as String),
                    )),
                  ],
                  onChanged: (v) {
                    setState(() => _panchayatFilter = v);
                    _reload();
                  },
                );
              },
            ),
          ],
        ],
      ),
      child: FutureBuilder<List<TenderSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AppLoadingState(
              message: 'Loading tenders...',
              skeletonLines: 5,
              style: AppLoadingStyle.list,
            );
          }
          if (snap.hasError) {
            return AppErrorState(
              message: userFacingMessage(snap.error!),
              onRetry: _reload,
            );
          }
          final tenders = snap.data ?? [];
          if (tenders.isEmpty) {
            return AppEmptyState(
              icon: Icons.assignment_outlined,
              title: 'No tenders yet',
              subtitle: 'Create your first tender to get started.',
              action: FilledButton.icon(
                onPressed: () => context.go(widget.isSuperAdmin ? '/superadmin/tenders/new' : '/tenders/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create tender'),
              ),
            );
          }
          return ListView.separated(
            itemCount: tenders.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _TenderRow(t: tenders[i], isSuperAdmin: widget.isSuperAdmin),
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
          color: isInvited
              ? (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade800)
              : (isDark ? Colors.green.shade200 : Colors.green.shade800),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
      backgroundColor: isInvited
          ? (isDark ? Colors.blueGrey.shade900.withValues(alpha: 0.6) : Colors.blueGrey.shade100)
          : (isDark ? Colors.green.shade900.withValues(alpha: 0.6) : Colors.lightGreen.shade100),
      side: BorderSide(
        color: isInvited
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
                vertical: 4,
              ),
              leading: const CircleAvatar(child: Icon(Icons.assignment_outlined)),
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
                    if (widget.isSuperAdmin && t.panchayatName != null)
                      Chip(
                        label: Text(
                          t.panchayatName!,
                          style: TextStyle(
                            color: isDark ? Colors.purple.shade200 : Colors.purple.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: isDark
                            ? Colors.purple.shade900.withValues(alpha: 0.6)
                            : Colors.purple.shade50,
                        side: BorderSide(
                          color: isDark ? Colors.purple.shade800 : Colors.purple.shade200,
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
                            color: isDark ? Colors.teal.shade200 : Colors.teal.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: isDark
                            ? Colors.teal.shade900.withValues(alpha: 0.6)
                            : Colors.teal.shade50,
                        side: BorderSide(
                          color: isDark ? Colors.teal.shade800 : Colors.teal.shade200,
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
              onTap: () => context.go(widget.isSuperAdmin ? '/superadmin/tenders/${t.id}' : '/tenders/${t.id}'),
            ),
          ),
        );
      },
    );
  }
}
